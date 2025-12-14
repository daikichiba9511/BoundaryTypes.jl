⚠️ **メンテナンスに関する注意**

**これはトイプロジェクトであり、積極的にメンテナンスされていません。**

このパッケージは、Julia で Pydantic ライクなバリデーションを探求するための教育的/実験的なプロジェクトとして作成されました。
コードは機能しますが、本番環境での使用は推奨しません。
Issue や Pull Request には対応しない可能性があります。

---

> ⚠️ **ステータス**
>
> BoundaryTypes.jl は現在、[@daikichiba9511](https://github.com/daikichiba9511)が開発している**サンプル/実験的なパッケージ**です。
>
> このリポジトリの主な目的は、Pydantic の開発者体験に着想を得つつも、それを複製するのではなく、
> *Julia ネイティブな境界バリデーションのアプローチ*を探求し、文書化することです。
>
> 安定版がリリースされるまで、API は予告なく変更される可能性があります。

# BoundaryTypes.jl

**Julia の型システム向けに設計された、入力境界での Pydantic ライクなバリデーション。**

BoundaryTypes.jl は、Julia のドメイン型を構築する _前_ に、**外部入力**（Dict / JSON / kwargs）を
バリデーションするための、軽量で宣言的な方法を提供します。

コアアイデアはシンプルです：

> **境界でバリデーションを行う。
> ドメイン構造体はシンプルに、型付けされ、常に妥当な状態を保つ。**

---

## モチベーション

Julia は型と多重ディスパッチを使ったドメインロジックのモデル化に優れています。
しかし、_外部入力_（API ペイロード、設定、ユーザー入力、JSON）のバリデーションは、しばしば以下のいずれかにつながります：

- コード全体に散在するアドホックなチェック、または
- Julia の型システムと戦う過度に設計されたスキーマシステム

BoundaryTypes.jl は**生の入力とドメイン型の間**に位置し、以下を提供します：

- エラー集約を伴う全フィールドバリデーション（Pydantic スタイルの UX）
- 最小限のマクロと明示的な制御（Julia スタイルの UX）
- 値が境界を越えた後のゼロランタイムコスト

---

## 主要機能

- ✅ **入力境界でのみ**Pydantic ライクなバリデーション
- ✅ 失敗前に**すべてのバリデーションエラーを収集**
- ✅ 宣言的で組み合わせ可能なバリデーションルール
- ✅ 構造体定義から推論されるデフォルト値とオプションフィールド
- ✅ 機密値のためのシークレット/編集サポート
- ✅ ドメイン構造体を小さく慣用的に保つ
- ✅ 重いスキーマや全体的なマジックなし
- ✅ JSON パースとバリデーションのサポート
- ✅ `model_copy`によるイミュータブル/ミュータブル構造体の更新
- ✅ `show_rules`によるイントロスペクション
- ✅ `schema`による JSON Schema 生成

---

## クイック例

```julia
using BoundaryTypes

@model struct Signup
    email::String
    password::String
    age::Int = 0
end

@rules Signup begin
    field(:email,
          regex(r"^[^@\s]+@[^@\s]+\.[^@\s]+$"))

    field(:password,
          minlen(12),
          regex(r"[A-Z]"),
          regex(r"[0-9]"),
          secret())

    field(:age,
          ge(0), le(150))
end

Signup(email="foo@example.com", password="short")
```

出力:

```
ValidationError with 2 error(s):
  - password [minlen]: string too short (got=***)
  - password [regex]: does not match required pattern (got=***)
```

---

## 設計哲学

BoundaryTypes.jl は意図的に Julia の型システムを置き換えようとは**しません**。

代わりに、明確な分離を強制します：

```
[ 外部入力 ]
        ↓
   model_validate / try_model_validate   ← バリデーションはここで発生
        ↓
   ドメイン構造体      ← 常に妥当
```

### なぜこれが重要か

- ドメイン構造体はクリーンで高速なまま
- バリデーションロジックは集中化され明示的
- 無効な状態がコアロジックに漏れることはない
- テストと推論がシンプルになる

---

## モデルの定義

### `@model`

ドメイン構造体を宣言するには`@model`を使用します。
BoundaryTypes は自動的に以下を推論します：

- 必須フィールド
- デフォルト値
- オプションフィールド（`Union{Nothing,T}`）

```julia
@model struct User
    id::Int
    name::String
    age::Int = 0
    nickname::Union{Nothing,String} = nothing
end
```

推論ルール：

| 定義                            | 解釈                     |
| ------------------------------- | ------------------------ |
| `x::T`                          | 必須                     |
| `x::T = v`                      | デフォルト値             |
| `x::Union{Nothing,T}`           | オプション               |
| `x::Union{Nothing,T} = nothing` | デフォルト付きオプション |

---

## バリデーションルール

バリデーションルールは`@rules`を使用して構造体の**外部**で定義されます。

```julia
@rules User begin
    field(:name, minlen(1))
    field(:age, ge(0))
    field(:nickname, minlen(3))  # 値が存在する場合のみチェック
end
```

### 利用可能なルールビルダー

#### 文字列ルール

- `minlen(n)`
- `regex(re)`

#### 数値ルール

- `ge(n)`
- `le(n)`

#### プレゼンスルール

- `present()` — キーが入力に存在する必要がある
- `notnothing()` — 値が`nothing`であってはならない

#### セキュリティ

- `secret()` — エラーメッセージとログで値をマスク

#### カスタムルール

```julia
custom(x -> x % 2 == 0; code=:even, msg="must be even")
```

ルールは組み合わせ可能で、**フェイルファースト無しで**実行されます。

---

## デフォルト値とオプションフィールド

### デフォルト値はバリデーションされる

```julia
age::Int = 0
field(:age, ge(0))
```

`age`が欠落している場合、`0`が使用され、**バリデーションされます**。

### オプションフィールド（`Union{Nothing,T}`）

- 欠落または`nothing` → デフォルトで OK
- ルールは実際の値が存在する場合のみ実行される

```julia
nickname::Union{Nothing,String}
field(:nickname, minlen(3))
```

プレゼンスを明示的に強制するには：

```julia
field(:nickname, present())
field(:nickname, notnothing())
```

---

## パース API

### `model_validate`

```julia
value = model_validate(T, raw)
```

- `raw`: `Dict`、`NamedTuple`、またはキーワード引数
- 成功時に`T`を返す
- 失敗時に`ValidationError`をスロー

### `try_model_validate`

```julia
ok, result = try_model_validate(T, raw)
```

- `ok == true` → `result::T`
- `ok == false` → `result::ValidationError`

### `model_validate_json`

```julia
value = model_validate_json(T, json_string)
```

- `json_string`: JSON 形式の文字列
- JSON 文字列をパースし、型`T`に対してバリデーション
- 成功時に`T`を返す
- 失敗時に`ValidationError`をスロー

例：

```julia
json_str = """{"email":"user@example.com", "password":"SecurePass123", "age":25}"""
signup = model_validate_json(Signup, json_str)
```

### `try_model_validate_json`

```julia
ok, result = try_model_validate_json(T, json_string)
```

- `ok == true` → `result::T`
- `ok == false` → `result::ValidationError`
- `model_validate_json`の安全（スロー無し）版

---

## コンストラクタ統合

### 手動統合（推奨）

バリデーションをデフォルトの体験にするには：

```julia
User(; kwargs...) = model_validate(User, kwargs)
```

これにより以下が可能になります：

```julia
User(name="Alice", age=-1)
```

…自動的にバリデーションを通過し、
外部入力に生のコンストラクタを公開しません。

### `@validated_model`による自動統合

`@validated_model`マクロは、バリデーション済みキーワードコンストラクタを自動的に作成します：

```julia
@validated_model struct Account
    username::String
    email::String
    balance::Float64 = 0.0
end

@rules Account begin
    field(:username, minlen(3))
    field(:email, regex(r"@"))
    field(:balance, ge(0.0))
end

# コンストラクタが自動的にバリデーション
acc = Account(username="alice", email="alice@example.com")
# 無効な場合はValidationErrorをスロー
```

---

## エラーモデル

各バリデーションエラーには以下が含まれます：

- `path` — フィールドパス（将来のネストサポート）
- `code` — 機械可読エラーコード
- `message` — 人間可読の説明
- `got` — 問題のある値（`secret()`の場合はマスク）

機密値は決して漏れません。

---

## モデルの更新

### `model_copy`（イミュータブル構造体）

更新されたフィールド値で新しいインスタンスを作成：

```julia
user = model_validate(User, Dict(:name => "Alice", :email => "alice@example.com", :age => 25))
updated = model_copy(user, Dict(:age => 26))  # 新しいインスタンスを返す
```

- デフォルトで更新された値をバリデーション
- バリデーションをスキップするには`validate=false`を使用

### `model_copy!`（ミュータブル構造体）

ミュータブル構造体インスタンスをインプレースで更新：

```julia
model_copy!(mutable_user, Dict(:age => 31))  # インプレースで変更
```

---

## イントロスペクション

### `show_rules`

登録されたモデル型のバリデーションルールを表示：

```julia
show_rules(Signup)
# またはIOストリームを指定
show_rules(io, Signup)
```

### `schema`

モデルの JSON Schema（Draft 7）を生成：

```julia
json_schema = schema(Signup)
# JSON Schema Draft 7互換のDictを返す
```

以下の用途に便利です：

- API ドキュメント
- クライアントサイドバリデーション
- OpenAPI/Swagger との統合

---

## BoundaryTypes.jl が _でないもの_

- ❌ 完全なスキーマシステム
- ❌ シリアライゼーションフレームワーク
- ❌ Julia の型システムの置き換え
- ❌ Pydantic のクローン

これは設計上、**境界バリデーションライブラリ**です。

---

## 要件

- Julia **1.12+**（Project.toml で指定）

依存関係：

- JSON3（JSON パース用）

---

## 現在の機能

以下の機能が実装され、テストされています：

- ✅ 宣言的バリデーションのための`@model`と`@rules`マクロ
- ✅ 自動コンストラクタバリデーションのための`@validated_model`
- ✅ Dict/NamedTuple 入力のための`model_validate` / `try_model_validate`
- ✅ JSON 文字列のための`model_validate_json` / `try_model_validate_json`
- ✅ インスタンス更新のための`model_copy` / `model_copy!`
- ✅ イントロスペクションのための`show_rules`
- ✅ JSON Schema 生成のための`schema`
- ✅ バリデーションルール：`minlen`、`regex`、`ge`、`le`、`present`、`notnothing`、`secret`、`custom`
- ✅ 型ミスマッチ検出
- ✅ 余分なフィールド検出
- ✅ デフォルト値バリデーション
- ✅ オプションフィールド処理（`Union{Nothing,T}`）
- ✅ エラーメッセージでのシークレットフィールドマスキング

---

## ロードマップ

将来の拡張の可能性（コア設計を壊さずに）：

- 型強制（`"123"` → `Int`）
- コレクションバリデーション（`each(rule)`）
- ネストされたモデルバリデーション
- i18n エラーメッセージ

---

## ライセンス

MIT
