# Pydantic-like Validation for Julia

## Design Spec & Sample Code

## 目的

- Julia で **Pydantic に近い入力検証体験**を提供する
- ただし **Julia らしさ（型・multiple dispatch・明示的境界）を最優先**
- 外部入力（Dict / JSON / kwargs）に対して

  - **全フィールド・全ルールを検証**
  - **エラーを収集してから fail**

- Domain 型（struct）は **always-valid** を保証

---

## 設計方針（結論）

### 二層アーキテクチャ

```
[外部入力]
   ↓
model_validate / try_model_validate   ← Pydantic-like（全件検証）
   ↓
Domain struct      ← Julia-like（always-valid）
```

### 層ごとの責務

#### 1. Domain 層（Julia らしさ）

- `struct` は **薄い純データ**
- 不変条件は **inner constructor で fail-fast**
- invalid instance を絶対に作らない

#### 2. Boundary 層（Pydantic 風 UX）

- `model_validate(T, raw)` が唯一の入口
- 全フィールド検証・全エラー収集
- `@rules` で宣言的に検証ルールを追加
- default / optional は struct 定義から **自動推論**

---

## モデル定義（@model）

### 基本ルール

- 型・default・optional は **struct から推論**
- 冗長な `field(:x, Type, required())` は不要

### 推論規則

| struct 定義                     | 解釈               |
| ------------------------------- | ------------------ |
| `x::T`                          | required           |
| `x::T = v`                      | default = v        |
| `x::Union{Nothing,T}`           | optional           |
| `x::Union{Nothing,T} = nothing` | optional + default |

### 例

```julia
@model struct Signup
    email::String
    password::String
    age::Int = 0
    nickname::Union{Nothing,String} = nothing
end
```

---

## 検証ルール定義（@rules）

### 方針

- `field(:name, rule1, rule2, ...)`
- **ルールは関数を繋げるだけ**
- struct の中には書かない（縦に長くならない）

### 例

```julia
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

    field(:nickname,
          minlen(3))  # 値があるときだけ検証
end
```

---

## Validation セマンティクス

### required フィールド

- raw に無い → missing error
- 値があれば → 検証ルール適用

### default フィールド

- raw に無い → default を採用
- **default に対しても検証ルールを適用**

### optional フィールド（Union{Nothing,T}）

- missing / `nothing` → OK（原則ルールはスキップ）
- 実値がある → 検証ルール適用

### optional に対して強制したい場合

```julia
field(:nickname, present())     # missing を禁止
field(:nickname, notnothing())  # nothing を禁止
```

---

## ルール（Rule Builder）

### 基本ルール

```julia
minlen(n)
regex(re)
ge(n)
le(n)
```

### presence 系

```julia
present()     # key が存在すること
notnothing()  # 値が nothing でないこと
```

### secret（検証ではなく属性）

```julia
secret()
```

- エラー表示・ログ出力時に値をマスク
- セキュリティ事故防止

### カスタムルール

```julia
custom(x -> x % 2 == 0; code=:even, msg="must be even")
```

---

## model_validate API

### 基本

```julia
value = model_validate(T, raw)
```

- raw: `Dict`, `NamedTuple`, `kwargs`
- 全件検証 → 成功なら `T`
- エラーがあれば `ValidationError(errors)` を throw

### try_model_validate（推奨）

```julia
ok, result = try_model_validate(T, raw)
```

- `ok == true` → `result::T`
- `ok == false` → `result::ValidationError`

### model_validate_json

```julia
value = model_validate_json(T, json_string)
```

- JSON 文字列をパース・検証
- 成功なら `T`、失敗なら `ValidationError` を throw

```julia
json_str = """{"email":"user@example.com", "password":"SecurePass123"}"""
signup = model_validate_json(Signup, json_str)
```

---

## 開発者体験の最適化

### コンストラクタ誘導（重要）

```julia
Signup(; kwargs...) = model_validate(Signup, kwargs)
```

- `Signup(email="a@b.com", password="...")`
- 見た目はコンストラクタ、実体は `model_validate`
- validation を **強く誘導**できる

---

## エラー表現

```julia
FieldError(
  path    = [:password],
  code    = :minlen,
  message = "string too short",
  got     = "***",          # secret() の場合
)
```

- path は将来ネスト対応を想定
- code は機械処理向け
- message は人間向け

---

## 最小サンプルコード

```julia
@model struct Signup
    email::String
    password::String
end

@rules Signup begin
    field(:email, regex(r"@"))
    field(:password, minlen(12), secret())
end

Signup(email="foo@example.com", password="short")
# => ValidationError
#   - password [minlen]: string too short (got=***)
```

---

## なぜこの設計が Julia らしいか

- struct は **型と不変条件だけ**
- validation は **入力境界の責務**
- ルールは **関数合成・multiple dispatch と相性抜群**
- マクロは **spec 登録のみ**（重くならない）
- Domain と IO を分離でき、ML / ETL / API で再利用しやすい

---

## 今後の拡張ポイント（設計を壊さず追加可能）

1. coercion（`"123"` → `Int`）
2. `each(rule)`（配列要素検証）
3. ネストモデル（再帰的 parse）
4. JSON Schema / OpenAPI 生成
5. i18n 対応メッセージ

---

## まとめ

- **Pydantic の UX**と **Julia の哲学**を両立
- validation は「境界でだけ」強く
- Domain は型で守る
- ルールは関数で繋ぐだけ

この設計は **小さく始めて、後から強くできる**のが最大の利点です。

---

必要であれば、次はこの仕様を

- **実装テンプレ（1 ファイル）**
- **ライブラリ化前提のディレクトリ構成**
- **JSON 入力対応版**

のどれかに落とします。
