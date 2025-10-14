# ImageHarvester

A PowerShell script that recursively searches through directories and copies all image files to a specified destination with comprehensive logging.

## Features

- 🔍 **Recursive Search**: Scans all subfolders for image files
- 🖼️ **Multiple Formats**: Supports JPG, PNG, GIF, BMP, TIFF, WEBP, RAW, and more
- 📝 **Detailed Logging**: Creates comprehensive log files with timestamps
- 🔄 **Duplicate Handling**: Automatically renames duplicate files
- ⚡ **Progress Tracking**: Real-time progress display and file counter
- 🎨 **Color-coded Output**: Easy-to-read console output with color coding
- 🛡️ **Error Handling**: Continues processing even if individual files fail

## Supported Image Formats

- **Common**: JPG, JPEG, PNG, GIF, BMP, TIFF, TIF, WEBP, SVG, ICO
- **RAW Formats**: RAW, CR2, NEF, ARW, HEIC

## Usage

### Basic Usage
```powershell
.\ImageHarvester.ps1 -SourcePath "C:\Photos" -DestinationPath "D:\Backup\Images"

With Custom Log Location
powershell

.\ImageHarvester.ps1 -SourcePath "C:\Users\John\Pictures" -DestinationPath "E:\ImageCollection" -LogPath "C:\Logs\image_copy.log"

Parameters
Parameter	Description	Required
SourcePath	Source directory to search for images	Yes
DestinationPath	Destination directory for copied files	Yes
LogPath	Custom path for log file (optional)	No
Examples
📁 Basic Examples

1. Backup Personal Photos
powershell

.\ImageHarvester.ps1 -SourcePath "C:\Users\Alice\Pictures" -DestinationPath "D:\PhotoBackup\2024"

2. Collect Images from External Drive
powershell

.\ImageHarvester.ps1 -SourcePath "E:\DCIM" -DestinationPath "C:\SortedPhotos"

3. Organize Desktop Images
powershell

.\ImageHarvester.ps1 -SourcePath "C:\Users\Bob\Desktop" -DestinationPath "C:\OrganizedImages\Desktop"

🔧 Advanced Examples

4. With Custom Log Location
powershell

.\ImageHarvester.ps1 -SourcePath "F:\Photography" -DestinationPath "G:\Archive" -LogPath "C:\Temp\photo_log.txt"

5. Multiple Source Drives
powershell

# Copy from USB drive
.\ImageHarvester.ps1 -SourcePath "G:\" -DestinationPath "C:\Collected\USB_Photos"

# Copy from SD card
.\ImageHarvester.ps1 -SourcePath "H:\DCIM" -DestinationPath "C:\Collected\SDCard_Photos"

6. Network Drives and Shared Folders
powershell

.\ImageHarvester.ps1 -SourcePath "\\NAS\Photos\Family" -DestinationPath "C:\LocalBackup\FamilyPhotos"

🗂️ Real-World Scenarios

7. Consolidate Photos from Multiple User Profiles
powershell

.\ImageHarvester.ps1 -SourcePath "C:\Users" -DestinationPath "D:\CompanyPhotos\AllUsers"

8. Backup Camera RAW Files
powershell

.\ImageHarvester.ps1 -SourcePath "C:\CameraImports" -DestinationPath "E:\RAW_Backup" -LogPath "C:\Logs\raw_backup.log"

9. Website Image Assets Collection
powershell

.\ImageHarvester.ps1 -SourcePath "C:\WebProjects" -DestinationPath "D:\WebsiteAssets\Images"

10. Social Media Image Archive
powershell

.\ImageHarvester.ps1 -SourcePath "C:\SocialMedia\Downloads" -DestinationPath "D:\Archive\SocialMediaImages"

💼 Professional Use Cases

11. Photographer Workflow - Organize by Client
powershell

# Client A's photos
.\ImageHarvester.ps1 -SourcePath "C:\Photos\ClientA" -DestinationPath "D:\Deliverables\ClientA\AllImages"

# Client B's photos  
.\ImageHarvester.ps1 -SourcePath "C:\Photos\ClientB" -DestinationPath "D:\Deliverables\ClientB\AllImages"

12. Educational Institution - Collect Student Projects
powershell

.\ImageHarvester.ps1 -SourcePath "\\Server\StudentWork" -DestinationPath "D:\Faculty\ImageCollection\Semester1"

13. E-commerce Product Images
powershell

.\ImageHarvester.ps1 -SourcePath "C:\ProductPhotos" -DestinationPath "E:\Website\ProductImages\All"

🔄 Batch Processing Examples

14. Process Multiple Sources with Logging
powershell

# Create a batch script (ProcessAllImages.bat)
@echo off
echo Starting image collection process...
powershell -File "ImageHarvester.ps1" -SourcePath "C:\Source1" -DestinationPath "D:\Output1" -LogPath "C:\Logs\source1.log"
powershell -File "ImageHarvester.ps1" -SourcePath "C:\Source2" -DestinationPath "D:\Output2" -LogPath "C:\Logs\source2.log"
powershell -File "ImageHarvester.ps1" -SourcePath "C:\Source3" -DestinationPath "D:\Output3" -LogPath "C:\Logs\source3.log"
echo All image collections completed!

15. Scheduled Backup (Windows Task Scheduler)
powershell

# Use this command in Task Scheduler for daily backups
.\ImageHarvester.ps1 -SourcePath "C:\ImportantPhotos" -DestinationPath "D:\DailyBackup" -LogPath "C:\Logs\DailyBackup_%date%.log"

Output Structure
Console Output Example:
text

[2024-01-15 10:30:45] [1/150] COPIED: IMG_1234.jpg (2.45 MB, 0.12s)
[2024-01-15 10:30:46] [2/150] COPIED (renamed): IMG_1234.jpg -> IMG_1234_1.jpg (2.45 MB, 0.11s)
[2024-01-15 10:30:47] [3/150] ERROR: corrupt_image.jpg - Access denied

File Structure After Execution:
text

DestinationFolder/
├── IMG_1234.jpg
├── IMG_1234_1.jpg (duplicate renamed)
├── photo1.png
├── diagram.svg
└── ImageHarvester_log_20240115_103045.txt

Error Handling and Troubleshooting
Common Issues and Solutions:

1. "Execution Policy" Error
powershell

# Solution: Set execution policy
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

2. "Path Not Found" Error

    Verify source path exists

    Check for typos in directory names

    Ensure drive letters are correct

3. "Access Denied" Errors

    Run PowerShell as Administrator

    Check folder permissions

    Ensure destination drive has enough space

4. No Files Found

    Verify the source directory contains image files

    Check if file extensions are supported

    Ensure hidden files are included if needed

Performance Tips

    Large Collections: Script handles thousands of files efficiently

    Network Drives: May be slower but fully supported

    Progress Tracking: Cancel with Ctrl+C at any time

    Memory Usage: Processes files sequentially to minimize memory usage

License

Free to use and modify for personal and commercial projects.
Version

Current Version: 1.0
Support

For issues or feature requests, please check the script output and log files for detailed error information.
text


## Quick Reference Card

Also, here's a quick reference you can add as `QUICK_START.md`:

```markdown
# ImageHarvester - Quick Start

## 🚀 Most Common Uses:

**Basic Backup:**
```powershell
.\ImageHarvester.ps1 -SourcePath "C:\Photos" -DestinationPath "D:\Backup"

External Drive:
powershell

.\ImageHarvester.ps1 -SourcePath "E:\" -DestinationPath "C:\CollectedPhotos"

With Logging:
powershell

.\ImageHarvester.ps1 -SourcePath "C:\Pictures" -DestinationPath "D:\Output" -LogPath "C:\Logs\my_log.txt"

⚡ Pro Tips:

    Use Tab completion for paths in PowerShell

    Log files are automatically timestamped

    Duplicate files are automatically renamed

    Progress bar shows real-time status

🔧 Troubleshooting:
powershell

# If you get permission errors:
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser

# Run as Administrator if needed

📞 Need Help?

Check the log file created in your destination folder!
text


The examples now cover:
- ✅ **Basic usage** for beginners
- ✅ **Advanced scenarios** for power users  
- ✅ **Professional workflows** for business use
- ✅ **Batch processing** for multiple operations
- ✅ **Troubleshooting** common issues
- ✅ **Quick reference** for fast access

This makes the script much more user-friendly and accessible for all skill levels!

