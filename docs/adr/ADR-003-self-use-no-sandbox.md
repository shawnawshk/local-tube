# ADR-003 只给自己用:本地签名,不开 App Sandbox

状态:已采纳 | 2026-10-20

## 背景

接下来播放列表要读当前文件夹里的其他视频。开了 App Sandbox 的话,用户拖进来或 ⌘O 选中的只是那一个文件,app 只拿到这一个文件的权限,同文件夹的其他文件读不到。要读就得再让用户授权整个文件夹,还得存 security-scoped bookmark,下次启动才能继续读。

## 决策

用户确认只给自己用,所以:

- 不开 App Sandbox,直接按路径读当前文件夹。
- 本地签名(ad-hoc / 本机开发证书),不做 Developer ID 签名和公证。
- 构建产物自己放进 /Applications。

## 后果

- 接下来播放列表、按路径记进度都能直接实现,不用处理文件夹授权。
- 别人下载后,第一次打开会被 Gatekeeper 拦下,见下面的修订。
- 更正(2026-10-20):原来这里写「要分发就得开沙盒」,不对。沙盒只有上架 Mac App Store 才强制要求,用 DMG 分发不需要。要做到下载后双击就能打开,需要 Developer ID 签名加公证,公证还要求开 Hardened Runtime。

## 修订 2026-10-20:通过 GitHub Release 分发 DMG

用户决定把构建产物公开发布,签名仍然只做本地签名(用户已确认):

- 推 `v*` tag 时,`.github/workflows/release.yml` 在 `macos-26` runner 上跑测试,用 `scripts/make-dmg.sh` 打包 `LocalTube-<版本>.dmg`,再发布成 GitHub Release。版本号取自 tag。
- 本机实测:给下载来的 app 打上隔离标记后,`spctl --assess` 判定为 `rejected`;执行 `xattr -dr com.apple.quarantine /Applications/LocalTube.app` 后隔离标记被清掉,跟本机构建的版本一样(本机构建的从来没有这个标记,一直能直接打开)。README 写了这一步。
- 仍然不开沙盒,理由同上。
