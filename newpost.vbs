Option Explicit
Dim fso, postsDir, articleName, folderPath, mdFilePath, datetime, dateStr
Dim shell, folderName, mdFileName

Set fso = CreateObject("Scripting.FileSystemObject")
Set shell = CreateObject("WScript.Shell")

postsDir = "./posts"

' 检查并创建 posts 目录
If Not fso.FolderExists(postsDir) Then
    fso.CreateFolder postsDir
    MsgBox "当前目录下无posts目录，已自动创建。", vbInformation, "提示"
End If

' 输入文章名称（必填）
Do
    articleName = InputBox("请输入文章名称（必填）：", "新建文章")
    If articleName = "" Then
        MsgBox "文章名称不能为空，请重新输入", vbExclamation, "错误"
    Else
        Exit Do
    End If
Loop

' 获取当前日期
datetime = Now()
dateStr = Year(datetime) & "-" & Right("0" & Month(datetime), 2) & "-" & Right("0" & Day(datetime), 2)

' 构建路径
folderName = articleName
folderPath = fso.BuildPath(postsDir, folderName)
mdFileName = folderName & ".md"
mdFilePath = fso.BuildPath(folderPath, mdFileName)

' 创建文件夹
If Not fso.FolderExists(folderPath) Then
    fso.CreateFolder folderPath
End If

' 写入 Markdown 文件
Dim mdFile
Set mdFile = fso.CreateTextFile(mdFilePath, True)
mdFile.WriteLine "---"
mdFile.WriteLine "title: " & articleName
mdFile.WriteLine "published: " & dateStr
mdFile.WriteLine "description: "
mdFile.WriteLine "image: "
mdFile.WriteLine "tags: []"
mdFile.WriteLine "category: "
mdFile.WriteLine "draft: false"
mdFile.WriteLine "---"
mdFile.Close

' 成功提示
MsgBox "生成成功！" & vbCrLf & vbCrLf & "文件路径：" & mdFilePath, vbInformation, "完成"

' 可选：自动打开文件夹
' shell.Run "explorer.exe /select," & mdFilePath