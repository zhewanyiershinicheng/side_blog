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

' 输入文章名称（必填 + 重名检测）
Do
    articleName = InputBox("请输入文章名称（必填）：", "新建文章")
    
    ' 判断：如果点击了取消/关闭，直接退出脚本
    If IsEmpty(articleName) Then
        WScript.Quit
    End If
    
    ' 判断：如果输入为空，提示重输
    If articleName = "" Then
        MsgBox "文章名称不能为空，请重新输入", vbExclamation, "错误"
    Else
        ' 构建路径，检查是否重名
        folderPath = fso.BuildPath(postsDir, articleName)
        If fso.FolderExists(folderPath) Then
            MsgBox "该文章名已存在，请重新输入", vbExclamation, "重名提示"
        Else
            ' 不重名，退出循环
            Exit Do
        End If
    End If
Loop

' 获取当前日期
datetime = Now()
dateStr = Year(datetime) & "-" & Right("0" & Month(datetime), 2) & "-" & Right("0" & Day(datetime), 2)

' 构建剩余路径
mdFileName = articleName & ".md"
mdFilePath = fso.BuildPath(folderPath, mdFileName)

' 创建文件夹
fso.CreateFolder folderPath

' 写入 Markdown 文件 - 最简洁可靠的 UTF-8 with BOM 方法
Dim content, stream
content = "---" & vbCrLf & _
    "title: " & articleName & vbCrLf & _
    "published: " & dateStr & vbCrLf & _
    "description: " & vbCrLf & _
    "image: " & vbCrLf & _
    "tags: []" & vbCrLf & _
    "category: " & vbCrLf & _
    "draft: false" & vbCrLf & _
    "---"

' 创建 ADODB.Stream 对象
Set stream = CreateObject("ADODB.Stream")

' 第一步：用文本模式生成 UTF-8 内容（不带 BOM）
stream.Type = 2 ' adTypeText
stream.Charset = "utf-8"
stream.Open
stream.WriteText content

' 第二步：切换到二进制模式，现在可以读取 UTF-8 字节
stream.Position = 0
stream.Type = 1 ' adTypeBinary

' 读取全部字节（ADODB.Stream 会自动添加 BOM）
Dim bytes
bytes = stream.Read

' 第三步：重新创建文件，写入完整内容
stream.Close
stream.Open
stream.Write bytes
stream.SaveToFile mdFilePath, 2 ' adSaveCreateOverWrite
stream.Close
Set stream = Nothing

' 成功提示
MsgBox "生成成功！" & vbCrLf & vbCrLf & "文件路径：" & mdFilePath, vbInformation, "完成"

' 释放所有对象
Set fso = Nothing
Set shell = Nothing

' 强制退出脚本
WScript.Quit
