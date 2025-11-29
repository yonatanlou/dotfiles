## Python Scripts

These scripts are used for various tasks in my workflow.


merge_google_takeout.py
=======================

This script safely extracts multiple .tgz files from Google Takeout and merges them to a destination directory, handling split folders across archives.

Usage
-----

```bash
python3 merge_google_takeout.py --source ~/Downloads/takeout-dec-2025 --dest /Volumes/KINGSTON/Yonatan personal gdrive/dec-2025
```

The script will prompt you to confirm the merge before proceeding.

If you want to run the script non-interactively, you can use the `--dry-run` flag:

```bash
python3 merge_google_takeout.py --source ~/Downloads/takeout-dec-2025 --dest /Volumes/KINGSTON/Yonatan personal gdrive/dec-2025 --dry-run
```

This will run the script in dry-run mode and print the output to a log file.

download_hf_models.py
=====================

In case the world will end, i will have an open source model for the rescue (given a gpu).

This script downloads the model from HuggingFace and saves it to a local directory.

Usage
-----

```bash
python3 download_hf_models.py --model_name openai/gpt-oss-120b --local_dir ~/dev/huggingface-models
```

