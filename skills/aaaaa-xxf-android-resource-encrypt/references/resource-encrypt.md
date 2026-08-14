# resource-encrypt

`resource-encrypt` 是一个面向 Android 业务模块的资源加密方案。它在构建期处理 `assets/` 和 `res/raw/` 中的指定资源，运行时再通过统一 API 解密读取。

当前 DSL 已切到新结构，不兼容旧写法：

- `input { ... }`
- `output { ... }`
- `verify { ... }`

旧的 `keyGeneratedClassName`、`keySupplierClassName`、`encryptAsset`、`encryptRaw`、`failOnCollision`、`preserve*` 配置都已经移除。

## 快速开始

```groovy
resourceEncrypt {
    enabled.set(true)
    moduleId.set('example-app')

    input {
        key {
            keySupplier { request ->
                request.uniqueKey()
            }
        }

        assets {
            encrypt('config/secret-demo.json', pathMappingExtensions: ['txt', 'doc', ''])
        }

        raw {
            encrypt('local_demo_payload.json')
            encrypt('zh-rCN', 'welcome_text.json', pathMappingExtensions: ['bin'])
        }
    }

    output {
        sourceConfig {
            className('com.example.app.generated.ResourceEncryptedBuildConfig.java')
        }
        pathGuardEnabled.set(true)
    }

    verify {
        failOnCollision.set(true)
        failOnPlaintextLeak.set(true)
        dryRun.set(false)
    }
}
```

## 新旧映射

- `input.key.keySupplier` 替代旧的 key 生成入口。
- `output.sourceConfig.className(...)` 替代旧的 `keyGeneratedClassName`。
- `input.assets.encrypt(...)` 和 `input.raw.encrypt(...)` 替代旧的 `encryptAsset(...)` / `encryptRaw(...)`。
- `verify.failOnCollision` 替代旧的 `output.failOnCollision`。
- `pathMappingExtensions` 替代旧的 `pathGuardExtensions`。
- `preserveExtension`、`preserveRelativePath`、`preserveFileName` 已删除。

## `input`

`input` 描述要参与加密的资源和 key 生成方式。

### `key`

`key` 必须提供 `keySupplier`，插件不再提供默认实现，也不再支持 `keySupplierClassName`。

```groovy
input {
    key {
        keySupplier { request ->
            request.randomKey()
        }
    }
}
```

`ResourceEncryptKeyRequest` 提供这些信息：

- `applicationId`
- `variantName`
- `flavorName`
- `channelName`
- `appVersionCode`
- `appVersionName`
- `moduleId`

并提供两个便捷方法：

- `uniqueKey()`：基于 `applicationId + variantName + flavorName + channelName` 生成稳定 key
- `randomKey()`：生成随机 key

业务侧可以自己选择是稳定 key 还是随机 key。

### `assets`

```groovy
input {
    assets {
        encrypt('config/secret-demo.json')
        encrypt('config/*.json')
        encrypt('config/secret-demo.json', pathMappingExtensions: ['txt', 'doc', ''])
    }
}
```

- `encrypt(path)`：加密单个 `assets` 文件
- `encrypt(path, pathMappingExtensions: [...])`：为这个文件指定允许映射的后缀候选

### `raw`

```groovy
input {
    raw {
        encrypt('local_demo_payload.json')
        encrypt('zh-rCN', 'welcome_text.json')
        encrypt('zh-rCN', 'welcome_text.json', pathMappingExtensions: ['bin', 'dat', ''])
    }
}
```

- `encrypt(path)`：加密 `res/raw` 文件
- `encrypt(qualifier, path)`：加密 `res/raw-qualifier` 文件
- `encrypt(..., pathMappingExtensions: [...])`：为这个文件指定允许映射的后缀候选

`pathMappingExtensions` 不是过滤输入文件的条件，而是控制 path guard 开启时最终映射出来的文件扩展名候选。

- 只对文件生效，目录不处理
- 可以包含多个字符串
- 可以包含 `''`，表示允许没有扩展名
- 如果没有配置，默认保留原始扩展名

## `output`

```groovy
output {
    sourceConfig {
        className('com.example.app.generated.ResourceEncryptedBuildConfig.kt')
    }
    pathGuardEnabled.set(true)
}
```

### `sourceConfig.className(...)`

- 必须写全名
- 必须包含文件名后缀，例如 `.java` 或 `.kt`
- 例子：
  - `com.example.app.generated.ResourceEncryptedBuildConfig.java`
  - `com.example.app.generated.ResourceEncryptedBuildConfig.kt`

### `pathGuardEnabled`

- 控制是否启用 path guard 相关输出策略
- 只有开启时，`pathMappingExtensions` 才会参与最终文件扩展名选择
- 关闭时，输出保留原始路径映射

## `verify`

```groovy
verify {
    failOnCollision.set(true)
    failOnPlaintextLeak.set(true)
    dryRun.set(false)
    failOnMissingConfiguredTargets.set(true)
}
```

- `failOnCollision`：同一个输出目标被多个输入命中时直接失败
- `failOnPlaintextLeak`：检查输出是否仍然是明文
- `dryRun`：只扫描和报告，不真正写出加密结果
- `failOnMissingConfiguredTargets`：配置了白名单但实际没有命中时是否失败

`failOnCollision` 现在只能放在 `verify` 里。

## 生成结果

`output.sourceConfig.className(...)` 会生成一个常量类，通常包含：

- `KEY_BASE64`
- `encryptedAssets`
- `encryptedRaw`

这类生成文件是给运行时解密入口使用的，不建议业务直接依赖它做核心业务逻辑。

## 运行时读取

运行时仍然沿用 `resource-encrypt-runtime` 的读取入口：

- `assets.open(...)`
- `resources.openRawResource(...)`

读取时传入生成的 `KEY_BASE64` 和对应的加密目标数组即可。

## 排错

- 先看 `scan`、`encrypt`、`verify` 相关任务产物
- 冲突优先检查 `verify.failOnCollision`
- 目标没命中优先检查 `input` 白名单和 `pathMappingExtensions`
- key 问题优先检查 `input.key.keySupplier` 返回值是否符合长度要求

## 本地联调

如果你在当前仓库里调试这套模块，通常先发布本地 Maven，再跑 demo 即可。
