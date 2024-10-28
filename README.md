# Comics OCR for macOS

A macOS Automator application and Swift script that provide efficient OCR processing for text and comic images on macOS. This tool is designed to process individual comic image files or entire directories (with recursive support), allowing for easy and accurate extraction of text from images. The application supports customisable row splitting for optimised OCR on comics with multiple text blocks split over several rows.

## Features

* **Batch Processing:** Select individual images or entire folders for OCR.
* **Recursive Processing:** Automatically process subdirectories when enabled.
* **Row Splitting:** Specify the number of horizontal rows for OCR, allowing finer control over text recognition in multi-panel comics.
* **Row Defaults:** Defaults to a single row for images with an aspect ratio close to 3.2 (e.g. three horizontal frames) or two rows for images with an aspect ratio close to 2.25 (e.g. two rows of 4 frames each).
* **Ignore vertical text:** Vertical text such as the name of the cartoonist, contact details, and copyright information is often written vertically along the edge of the comics frames. While we do not condone removing this from the image, the purpose of this script it to capture the speech bubble text from comics.
* Auto paragraphs: Each sentence (ending in a period, exclamation mark, or question mark) is separated by a blank line.

## Download

You can either download the latest version from the releases page, or compile the app yourself using the instructions below.

## Desktop App Usage

1.	Launch the App: Double-click the app icon.
2.	Select Files or Folders: Choose single or multiple files or whole folders for OCR processing. The app will create `.txt` files in the same directories as the images.

## Command Line Usage

For command-line usage, run the compiled script directly:

```sh
# Process a single file
./macos-comic-ocr -f <file_path>

# Process a directory
./macos-comic-ocr -d <directory_path>

# Recursive processing
./macos-comic-ocr -d <directory_path> -r

# Specify rows for OCR
./macos-comic-ocr -f <file_path> -n 2
```

### Parameters

The following command line parameters may be used:

```
-f <file_path>: Process a single file.
-d <directory_path>: Process all images in a specified directory.
-r: Enable recursive processing for subdirectories.
-n <num>: Specify the number of horizontal rows for OCR splitting, defaulting to automatic detection if not specified.
```

## Compilation and Installation

1.	Compile the Swift Script:

```zsh
swiftc macos-comic-ocr.swift -o macos-comic-ocr
```

If you intend only to use it from the command line, move the `macos-comic-ocr` executable to a convenient location, such as `/usr/local/bin`.

2.	Set Up the Automator Application:
* Open **Automator** and create a new Application.
* Add an **Ask for Finder Items** action to select files or folders.
* Add a **Run AppleScript** action, and add the following script:
	
```
on run {input, parameters}
    set appPath to POSIX path of (path to me)
    return {appPath} & input
end run
```
	
* Add a **Run Shell Script** action and set Shell to `/bin/bash`; Set **Pass input** to as arguments.
* Use the following script to call `macos-comic-ocr`:

```bash
#!/bin/bash

# Get the application path from the first argument
APP_PATH="$1"
shift  # Shift to the next argument, so $@ contains only the input items

# Path to the embedded executable
OCR_EXECUTABLE="$APP_PATH/Contents/MacOS/macos-comic-ocr"

# Initialize an array to store directories
dirs_to_open=()

# Loop through each selected item
for item in "$@"; do
    if [ -d "$item" ]; then
        # Process as a directory
        "$OCR_EXECUTABLE" -d "$item"
        # Add the directory to the array
        dirs_to_open+=("$item")
    else
        # Process as a single file
        "$OCR_EXECUTABLE" -f "$item"
        # Get the directory containing the file
        dir="$(dirname "$item")"
        # Add the directory to the array
        dirs_to_open+=("$dir")
    fi
done

# Remove duplicates from dirs_to_open
unique_dirs=($(printf "%s\n" "${dirs_to_open[@]}" | sort -u))

# Open each directory in Finder
for dir in "${unique_dirs[@]}"; do
    open "$dir"
done
```

* Save the Automator application with a descriptive name, like **Comics OCR**.

3.	Embed the Script and Icon:
* Right-click your saved Automator app, select **Show Package Contents**.
* Place `macos-comic-ocr` inside **Contents/MacOS**.
* (Optional) Place your custom icon (`AppIcon.icns`) in **Contents/Resources** and set it in `Info.plist`:

```xml
<key>CFBundleIconFile</key>
<string>AppIcon</string>
```

## License

This project is licensed under the GNU Public License.
