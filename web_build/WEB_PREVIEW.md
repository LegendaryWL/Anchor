# Godot 网页版预览说明

这个文件夹是 Godot 的 Web 导出结果。不要直接双击打开 `index.html`，浏览器的本地文件模式经常会让 `.wasm` / `.pck` 加载失败。请用本地 HTTP 服务器打开。

## 本地运行

进入这个文件夹：

```bash
cd "/home/abcd/Documents/gamejam/cicg2026/anchor/Anchor/web_build"
```

启动本地服务器：

```bash
python3 -m http.server 8060
```

浏览器打开：

```text
http://localhost:8060/
```

停止服务器：在终端按 `Ctrl + C`。

## 端口被占用怎么办

如果 `8060` 已经被占用，可以换一个端口：

```bash
python3 -m http.server 8080
```

然后打开：

```text
http://localhost:8080/
```

如果想杀掉占用 `8060` 的进程：

```bash
fuser -k 8060/tcp
```

如果系统没有 `fuser`，可以试：

```bash
lsof -ti :8060 | xargs kill
```

## 分享或部署时需要带上的文件

这些文件必须放在一起，不能只发 `index.html`：

```text
index.html
index.js
index.wasm
index.pck
index.audio.worklet.js
index.audio.position.worklet.js
index.png
index.icon.png
index.apple-touch-icon.png
```

## 重新导出

在 Godot 里：

```text
Project -> Export... -> Web -> Export Project
```

导出路径填：

```text
../web_build/index.html
```

这样导出的文件会进入 `web_build/`，并继续保持 `index.*` 命名，队友打开 `http://localhost:8060/` 就能看。

## 注意事项

- Web 导出请使用 GDScript，不要用 C#。
- 模型和贴图尽量小一点，浏览器性能比较吃紧。
- 提交到仓库时要提交整套导出文件，不要只提交 `index.html`。
- `.godot/` 是本地缓存目录，一般不要提交。
