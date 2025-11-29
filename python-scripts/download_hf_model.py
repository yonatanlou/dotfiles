#!/usr/bin/env python3
"""
Download LLM models from Hugging Face to a specified folder.

Usage:
    python download_hf_model.py meta-llama/Llama-2-7b-hf --dest /path/to/models
    python download_hf_model.py mistralai/Mistral-7B-v0.1 --dest ./models --token YOUR_TOKEN
"""

import argparse
import os
import sys
from pathlib import Path

from huggingface_hub import snapshot_download
from huggingface_hub.utils import GatedRepoError, RepositoryNotFoundError


def download_model(
    model_id: str,
    dest_dir: Path,
    revision: str = "main",
    token: str | None = None,
) -> Path:
    """Download a model from Hugging Face Hub."""
    dest_dir.mkdir(parents=True, exist_ok=True)

    local_dir = dest_dir / model_id.replace("/", "--")

    print(f"Downloading: {model_id}")
    print(f"Revision: {revision}")
    print(f"Destination: {local_dir}")
    print("-" * 60)

    try:
        path = snapshot_download(
            repo_id=model_id,
            revision=revision,
            local_dir=local_dir,
            token=token,
            resume_download=True,
        )
        return Path(path)

    except GatedRepoError:
        print(f"\nError: '{model_id}' is a gated model.")
        print("You need to:")
        print("  1. Accept the license at https://huggingface.co/" + model_id)
        print("  2. Provide a token via --token or HF_TOKEN env var")
        sys.exit(1)

    except RepositoryNotFoundError:
        print(f"\nError: Model '{model_id}' not found on Hugging Face Hub.")
        sys.exit(1)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Download LLM models from Hugging Face Hub"
    )
    parser.add_argument(
        "model",
        help="Model ID (e.g., meta-llama/Llama-2-7b-hf)"
    )
    parser.add_argument(
        "--dest",
        type=Path,
        required=True,
        help="Destination folder for the model"
    )
    parser.add_argument(
        "--revision",
        default="main",
        help="Model revision/branch (default: main)"
    )
    parser.add_argument(
        "--token",
        default=os.environ.get("HF_TOKEN"),
        help="Hugging Face token (or set HF_TOKEN env var)"
    )

    args = parser.parse_args()

    path = download_model(
        model_id=args.model,
        dest_dir=args.dest,
        revision=args.revision,
        token=args.token,
    )

    print("-" * 60)
    print(f"✓ Downloaded to: {path}")


if __name__ == "__main__":
    main()
