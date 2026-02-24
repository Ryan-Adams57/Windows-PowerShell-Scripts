Add-Type -AssemblyName Microsoft.VisualBasic

function Restart-Prompt {
    $response = [Microsoft.VisualBasic.Interaction]::MsgBox(
        "IT is rebooting your machine. Save your work. Cancel to abort.", 
        [Microsoft.VisualBasic.MsgBoxStyle]::OkCancel + [Microsoft.VisualBasic.MsgBoxStyle]::Information, 
        "IT"
    )

    if ($response -eq [Microsoft.VisualBasic.MsgBoxResult]::Ok) {
        [Microsoft.VisualBasic.Interaction]::MsgBox("Reboot in 5 minutes.", "OkOnly,Information","IT")
        shutdown /r /t 300
    } else {
        [Microsoft.VisualBasic.Interaction]::MsgBox("Reboot canceled.", "OkOnly,Information","IT")
    }
}

Restart-Prompt
