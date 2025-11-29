#!/usr/bin/env python3
"""
Google Takeout Merger - Extract and merge multi-part Google Takeout archives.

This script safely extracts multiple .tgz files from Google Takeout and merges
them to a destination directory, handling split folders across archives.
"""

import argparse
import logging
import shutil
import subprocess
import sys
import tarfile
from datetime import datetime
from pathlib import Path
from typing import List, Optional

from tqdm import tqdm


class ValidationError(Exception):
    """Raised when environment validation fails."""
    pass


class ValidationService:
    """Validates environment prerequisites before extraction."""

    def __init__(self, source_dir: Path, dest_dir: Path, external_drive: Path):
        self.source_dir = source_dir
        self.dest_dir = dest_dir
        self.external_drive = external_drive

    def validate(self) -> List[Path]:
        """Validate all prerequisites and return list of .tgz files."""
        self._check_external_drive()
        self._check_source_directory()
        tgz_files = self._find_tgz_files()
        self._check_rsync_available()
        return tgz_files

    def _check_external_drive(self) -> None:
        if not self.external_drive.exists():
            raise ValidationError(
                f"External drive not mounted: {self.external_drive}"
            )
        logging.info(f"✓ External drive mounted: {self.external_drive}")

    def _check_source_directory(self) -> None:
        if not self.source_dir.exists():
            raise ValidationError(
                f"Source directory not found: {self.source_dir}"
            )
        logging.info(f"✓ Source directory exists: {self.source_dir}")

    def _find_tgz_files(self) -> List[Path]:
        tgz_files = sorted(self.source_dir.glob("takeout-*.tgz"))
        if not tgz_files:
            raise ValidationError(
                f"No takeout-*.tgz files found in {self.source_dir}"
            )
        logging.info(f"✓ Found {len(tgz_files)} .tgz files")
        return tgz_files

    def _check_rsync_available(self) -> None:
        try:
            subprocess.run(
                ["rsync", "--version"],
                capture_output=True,
                check=True
            )
            logging.info("✓ rsync is available")
        except (subprocess.CalledProcessError, FileNotFoundError):
            raise ValidationError("rsync not found. Please install rsync.")


class TakeoutExtractor:
    """Handles extraction of a single Google Takeout .tgz archive."""

    def __init__(self, temp_dir: Path):
        self.temp_dir = temp_dir

    def extract(self, tgz_file: Path) -> None:
        """Extract a single .tgz file to temp directory with progress."""
        self.temp_dir.mkdir(parents=True, exist_ok=True)
        logging.info(f"Extracting {tgz_file.name} to: {self.temp_dir}")

        try:
            with tarfile.open(tgz_file, "r:gz") as tar:
                members = tar.getmembers()
                for member in tqdm(
                    members,
                    desc=f"  {tgz_file.name}",
                    unit="file",
                    leave=False
                ):
                    tar.extract(member, self.temp_dir)
            logging.info(f"✓ Extracted {tgz_file.name}")
        except Exception as e:
            logging.error(f"Failed to extract {tgz_file}: {e}")
            raise

    def cleanup(self) -> None:
        """Remove all extracted files from temp directory."""
        if self.temp_dir.exists():
            shutil.rmtree(self.temp_dir)
            logging.info(f"✓ Cleaned up temp: {self.temp_dir}")


class DirectoryMerger:
    """Handles directory merging using rsync."""

    def __init__(self, source_dir: Path, dest_dir: Path, log_file: Path):
        self.source_dir = source_dir
        self.dest_dir = dest_dir
        self.log_file = log_file

    def preview_merge(self) -> bool:
        """Show dry-run preview and ask for confirmation."""
        logging.info("\n" + "="*60)
        logging.info("DRY RUN PREVIEW - No changes will be made")
        logging.info("="*60)

        result = self._run_rsync(dry_run=True)

        if result.returncode != 0:
            logging.error("Dry-run failed. Check the output above.")
            return False

        print("\n" + "="*60)
        response = input("Proceed with merge? [y/N]: ").strip().lower()
        return response == 'y'

    def merge(self) -> None:
        """Perform actual merge with progress."""
        logging.info("\n" + "="*60)
        logging.info("MERGING FILES")
        logging.info("="*60)

        result = self._run_rsync(dry_run=False)

        if result.returncode != 0:
            raise RuntimeError("Merge failed. Check logs for details.")

        logging.info("✓ Merge completed successfully")

    def _run_rsync(self, dry_run: bool = False) -> subprocess.CompletedProcess:
        """Run rsync with appropriate flags."""
        cmd = [
            "rsync",
            "-avu",
            "--progress",
            "--stats",
            "--itemize-changes",
        ]

        if dry_run:
            cmd.append("--dry-run")

        cmd.extend([
            f"{self.source_dir}/",
            str(self.dest_dir),
        ])

        log_file_path = self.log_file if not dry_run else self.log_file.with_suffix('.dryrun.log')

        result = subprocess.run(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
        )

        output = result.stdout.decode('utf-8', errors='replace')

        with open(log_file_path, 'w', encoding='utf-8') as log:
            log.write(output)

        self._print_rsync_output(output, dry_run)

        return result

    def _print_rsync_output(self, output: str, dry_run: bool) -> None:
        """Print formatted rsync output, highlighting updates."""
        updated_files = []

        for line in output.split('\n'):
            if line.startswith('>f'):
                item_type = line.split()[0]
                if 't' in item_type or 's' in item_type:
                    file_path = ' '.join(line.split()[1:])
                    updated_files.append(file_path)
                    print(f"  UPDATE: {file_path}")
            elif line.strip() and not line.startswith('sending') and not line.startswith('total'):
                print(line)

        if updated_files:
            mode = "WOULD UPDATE" if dry_run else "UPDATED"
            logging.info(f"\n{mode} {len(updated_files)} existing file(s):")
            for file_path in updated_files:
                logging.info(f"  - {file_path}")


class TakeoutMerger:
    """Orchestrates the complete Google Takeout merge process."""

    def __init__(
        self,
        source_dir: Path,
        dest_dir: Path,
        temp_dir: Optional[Path] = None,
    ):
        self.source_dir = source_dir.expanduser()
        self.dest_dir = dest_dir
        self.temp_dir = temp_dir or Path.home() / "Downloads" / "takeout-extracted-temp"
        self.external_drive = Path("/Volumes/KINGSTON")

        timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
        self.log_file = Path.home() / "Downloads" / f"takeout-merge-{timestamp}.log"

        self._setup_logging()

    def _setup_logging(self) -> None:
        """Configure logging to both file and console."""
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(levelname)s - %(message)s',
            handlers=[
                logging.FileHandler(self.log_file),
                logging.StreamHandler(sys.stdout)
            ]
        )

    def run(self) -> None:
        """Execute the complete merge process iteratively."""
        start_time = datetime.now()

        try:
            logging.info("="*60)
            logging.info("Google Takeout Merger (Iterative)")
            logging.info("="*60)

            validator = ValidationService(
                self.source_dir,
                self.dest_dir,
                self.external_drive
            )
            tgz_files = validator.validate()

            extractor = TakeoutExtractor(self.temp_dir)

            for i, tgz_file in enumerate(tgz_files):
                logging.info(f"\n[{i+1}/{len(tgz_files)}] Processing: {tgz_file.name}")

                extractor.extract(tgz_file)

                merger = DirectoryMerger(
                    self.temp_dir,
                    self.dest_dir,
                    self.log_file
                )

                if i == 0:
                    if not merger.preview_merge():
                        logging.info("Merge cancelled by user")
                        extractor.cleanup()
                        return

                merger.merge()
                extractor.cleanup()

            self._print_summary(start_time, len(tgz_files))

        except Exception as e:
            logging.error(f"Error: {e}")
            raise

    def _print_summary(self, start_time: datetime, archives_processed: int) -> None:
        """Print operation summary."""
        duration = datetime.now() - start_time

        logging.info("\n" + "="*60)
        logging.info("SUMMARY")
        logging.info("="*60)
        logging.info(f"Archives processed: {archives_processed}")
        logging.info(f"Duration: {duration}")
        logging.info(f"Log file: {self.log_file}")

        if self.dest_dir.exists():
            total_files = sum(1 for _ in self.dest_dir.rglob('*') if _.is_file())
            logging.info(f"Total files in destination: {total_files}")


def main() -> None:
    """Main entry point with CLI argument parsing."""
    parser = argparse.ArgumentParser(
        description="Extract and merge Google Takeout archives"
    )
    parser.add_argument(
        "--source",
        type=Path,
        default=Path.home() / ".Downloads" / "takeout-dec-2025",
        help="Source directory containing .tgz files"
    )
    parser.add_argument(
        "--dest",
        type=Path,
        default=Path("/Volumes/KINGSTON/Yonatan personal gdrive/dec-2025"),
        help="Destination directory for merged files"
    )
    parser.add_argument(
        "--temp",
        type=Path,
        help="Temporary extraction directory (default: ~/Downloads/takeout-extracted-temp)"
    )

    args = parser.parse_args()

    merger = TakeoutMerger(
        source_dir=args.source,
        dest_dir=args.dest,
        temp_dir=args.temp,
    )

    try:
        merger.run()
    except KeyboardInterrupt:
        print("\n\nOperation cancelled by user")
        sys.exit(1)
    except Exception as e:
        print(f"\nFatal error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
