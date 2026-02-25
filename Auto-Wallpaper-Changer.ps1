# Get the screen dimensions
Add-Type -AssemblyName System.Windows.Forms
$screen = [System.Windows.Forms.Screen]::PrimaryScreen
$screenWidth = $screen.Bounds.Width
$screenHeight = $screen.Bounds.Height
# Add the C# code to define the SystemParametersInfo function
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public class WallpaperChanger {
    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
}
"@

# Add references to the assemblies that contain the Screen and Graphics classes
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Set the path to the folder containing images
$imageFolderPath = "C:\Users\UserName\Pictures\wallpapers"  #change to your custom path with your images

# Get all image files in the folder
$imageFiles = Get-ChildItem -Path $imageFolderPath -Include *.jpg,*.jpeg,*.png,*.bmp,*.gif -Recurse | Where-Object { !$_.PSIsContainer }

# Check if there are any image files
if ($imageFiles.Count -gt 0) {
    # Randomly choose an image
    $randomImage = Get-Random -InputObject $imageFiles

    # Get the screen resolution
    $screen = [System.Windows.Forms.Screen]::PrimaryScreen
    $screenWidth = $screen.Bounds.Width
    $screenHeight = $screen.Bounds.Height

    # Load the chosen image
    $image = [System.Drawing.Image]::FromFile($randomImage.FullName)

    # Create a new Bitmap object with the screen resolution
    $resizedImage = New-Object Drawing.Bitmap $screenWidth, $screenHeight

    # Create a graphics object from the bitmap
    $graphics = [System.Drawing.Graphics]::FromImage($resizedImage)

    # Draw the image onto the bitmap, scaled to fit the screen resolution
    $graphics.DrawImage($image, 0, 0, $screenWidth, $screenHeight)

    # Save the bitmap as a temporary image file
    $tempImagePath = Join-Path ([IO.Path]::GetTempPath()) "wallpaper.bmp"
    $resizedImage.Save($tempImagePath, [System.Drawing.Imaging.ImageFormat]::Bmp)

    # Set the temporary image as the desktop wallpaper
    [WallpaperChanger]::SystemParametersInfo(20, 0, $tempImagePath, 3)
    Write-Host "Desktop wallpaper set to: $($randomImage.FullName)"

    # Dispose the graphics object and the image objects
    $graphics.Dispose()
    $image.Dispose()
    $resizedImage.Dispose()
} else {
    Write-Host "No image files found in the specified folder."
}
