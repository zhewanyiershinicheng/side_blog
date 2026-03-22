@echo off
chcp 65001
setlocal enabledelayedexpansion

set POSTS_DIR=./posts


if not exist "%POSTS_DIR%" (
    md "%POSTS_DIR%"
    echo 当前目录下无posts目录，已自动创建。请注意这意味着后续需要自行覆盖到可提交的目录下。
)

echo ======================
echo 请输入文章名称（必填）：
echo ======================

:again
set "ARTICLE_NAME="
set /p "ARTICLE_NAME="

if "!ARTICLE_NAME!"=="" (
    echo ❌ 文章名称不能为空，请重新输入：
    goto again
)

for /f "tokens=2 delims==" %%a in ('wmic os get localdatetime /value 2^>nul') do set "datetime=%%a"
set DATE_STR=!datetime:~0,4!-!datetime:~4,2!-!datetime:~6,2!

set FOLDER_NAME=!ARTICLE_NAME!
set FOLDER_PATH=%POSTS_DIR%\%FOLDER_NAME%
set MD_FILE_NAME=%FOLDER_NAME%.md
set MD_FILE_PATH=%FOLDER_PATH%\%MD_FILE_NAME%


if not exist "!FOLDER_PATH!" (
    md "!FOLDER_PATH!"
    echo ✅ 已创建文件夹：!FOLDER_PATH!
) else (
    echo ⚠️ 文件夹已存在：!FOLDER_PATH!
)

echo --- > "!MD_FILE_PATH!"
echo title: !ARTICLE_NAME! >> "!MD_FILE_PATH!"
echo published: !DATE_STR! >> "!MD_FILE_PATH!"
echo description: >> "!MD_FILE_PATH!"
echo image: >> "!MD_FILE_PATH!"
echo tags: [] >> "!MD_FILE_PATH!"
echo category: >> "!MD_FILE_PATH!" 
draft: false >> "!MD_FILE_PATH!"
echo --- >> "!MD_FILE_PATH!"

echo.
echo 🎉 生成成功！
echo.

pause
endlocal