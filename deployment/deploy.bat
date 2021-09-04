@REM 简单的部署方式，将public/目录整体拷贝到服务端的静态网站目录
@ECHO OFF
scp -P 26363 -r ../public git@45.78.8.221:/usr/share/nginx/hugo
IF ERRORLEVEL 0 GOTO 0
IF ERRORLEVEL 1 GOTO 1
:0
ECHO 上传成功
exit 0
:1
ECHO 传上失败，请稍后重试
exit 1