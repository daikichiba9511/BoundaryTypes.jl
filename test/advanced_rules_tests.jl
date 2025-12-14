@testset "Advanced String Rules" begin
    @testset "email() validation" begin
        @model struct EmailUser
            email::String
        end

        @rules EmailUser begin
            field(:email, email())
        end

        # Valid emails
        ok, result = try_model_validate(EmailUser, Dict(:email => "user@example.com"))
        @test ok
        @test result.email == "user@example.com"

        ok, result = try_model_validate(EmailUser, Dict(:email => "test.user+tag@subdomain.example.co.uk"))
        @test ok

        ok, result = try_model_validate(EmailUser, Dict(:email => "user_name@example-domain.com"))
        @test ok

        # Invalid emails
        ok, err = try_model_validate(EmailUser, Dict(:email => "not-an-email"))
        @test !ok
        @test any(e -> e.code == :email && e.path == [:email], err.errors)

        ok, err = try_model_validate(EmailUser, Dict(:email => "@example.com"))
        @test !ok

        ok, err = try_model_validate(EmailUser, Dict(:email => "user@"))
        @test !ok

        ok, err = try_model_validate(EmailUser, Dict(:email => "user @example.com"))
        @test !ok
    end

    @testset "url() validation" begin
        @model struct Bookmark
            url::String
        end

        @rules Bookmark begin
            field(:url, url())
        end

        # Valid URLs
        ok, result = try_model_validate(Bookmark, Dict(:url => "https://example.com"))
        @test ok

        ok, result = try_model_validate(Bookmark, Dict(:url => "http://subdomain.example.com/path/to/page"))
        @test ok

        ok, result = try_model_validate(Bookmark, Dict(:url => "https://example.com:8080/path?query=value"))
        @test ok

        ok, result = try_model_validate(Bookmark, Dict(:url => "ftp://files.example.com"))
        @test ok

        # Invalid URLs
        ok, err = try_model_validate(Bookmark, Dict(:url => "not-a-url"))
        @test !ok
        @test any(e -> e.code == :url && e.path == [:url], err.errors)

        ok, err = try_model_validate(Bookmark, Dict(:url => "example.com"))
        @test !ok

        ok, err = try_model_validate(Bookmark, Dict(:url => "//example.com"))
        @test !ok
    end

    @testset "uuid() validation" begin
        @model struct Resource
            id::String
        end

        @rules Resource begin
            field(:id, uuid())
        end

        # Valid UUIDs (hyphenated)
        ok, result = try_model_validate(Resource, Dict(:id => "550e8400-e29b-41d4-a716-446655440000"))
        @test ok

        ok, result = try_model_validate(Resource, Dict(:id => "6ba7b810-9dad-11d1-80b4-00c04fd430c8"))
        @test ok

        # Valid UUIDs (non-hyphenated)
        ok, result = try_model_validate(Resource, Dict(:id => "550e8400e29b41d4a716446655440000"))
        @test ok

        # Invalid UUIDs
        ok, err = try_model_validate(Resource, Dict(:id => "not-a-uuid"))
        @test !ok
        @test any(e -> e.code == :uuid && e.path == [:id], err.errors)

        ok, err = try_model_validate(Resource, Dict(:id => "550e8400-e29b-41d4-a716"))
        @test !ok

        ok, err = try_model_validate(Resource, Dict(:id => "ZZZZZZZZ-e29b-41d4-a716-446655440000"))
        @test !ok
    end

    @testset "choices() validation" begin
        @model struct Task
            status::String
            priority::String
        end

        @rules Task begin
            field(:status, choices(["pending", "active", "completed", "archived"]))
            field(:priority, choices(["low", "medium", "high"]))
        end

        # Valid choices
        ok, result = try_model_validate(Task, Dict(:status => "active", :priority => "high"))
        @test ok
        @test result.status == "active"
        @test result.priority == "high"

        ok, result = try_model_validate(Task, Dict(:status => "pending", :priority => "low"))
        @test ok

        # Invalid choice - status
        ok, err = try_model_validate(Task, Dict(:status => "invalid", :priority => "high"))
        @test !ok
        @test any(e -> e.code == :choices && e.path == [:status], err.errors)

        # Invalid choice - priority
        ok, err = try_model_validate(Task, Dict(:status => "active", :priority => "urgent"))
        @test !ok
        @test any(e -> e.code == :choices && e.path == [:priority], err.errors)

        # Both invalid
        ok, err = try_model_validate(Task, Dict(:status => "invalid", :priority => "urgent"))
        @test !ok
        @test count(e -> e.code == :choices, err.errors) == 2
    end

    @testset "choices() with numbers" begin
        @model struct Config
            port::Int
        end

        @rules Config begin
            field(:port, choices([80, 443, 8080, 3000]))
        end

        # Valid
        ok, result = try_model_validate(Config, Dict(:port => 443))
        @test ok

        # Invalid
        ok, err = try_model_validate(Config, Dict(:port => 9999))
        @test !ok
        @test any(e -> e.code == :choices, err.errors)
    end
end

@testset "Advanced Numeric Rules" begin
    @testset "gt() validation" begin
        @model struct Product
            price::Float64
            discount::Float64
        end

        @rules Product begin
            field(:price, gt(0.0))
            field(:discount, gt(0.0))
        end

        # Valid - values greater than 0
        ok, result = try_model_validate(Product, Dict(:price => 10.0, :discount => 5.0))
        @test ok

        ok, result = try_model_validate(Product, Dict(:price => 0.01, :discount => 0.01))
        @test ok

        # Invalid - equal to 0
        ok, err = try_model_validate(Product, Dict(:price => 0.0, :discount => 5.0))
        @test !ok
        @test any(e -> e.code == :gt && e.path == [:price], err.errors)

        # Invalid - less than 0
        ok, err = try_model_validate(Product, Dict(:price => -10.0, :discount => 5.0))
        @test !ok
        @test any(e -> e.code == :gt, err.errors)
    end

    @testset "lt() validation" begin
        @model struct Measurement
            temperature::Float64
            humidity::Float64
        end

        @rules Measurement begin
            field(:temperature, lt(100.0))
            field(:humidity, lt(100.0))
        end

        # Valid - values less than 100
        ok, result = try_model_validate(Measurement, Dict(:temperature => 25.0, :humidity => 60.0))
        @test ok

        ok, result = try_model_validate(Measurement, Dict(:temperature => 99.99, :humidity => 99.99))
        @test ok

        # Invalid - equal to 100
        ok, err = try_model_validate(Measurement, Dict(:temperature => 100.0, :humidity => 60.0))
        @test !ok
        @test any(e -> e.code == :lt && e.path == [:temperature], err.errors)

        # Invalid - greater than 100
        ok, err = try_model_validate(Measurement, Dict(:temperature => 105.0, :humidity => 60.0))
        @test !ok
    end

    @testset "between() validation" begin
        @model struct Rating
            score::Int
            confidence::Float64
        end

        @rules Rating begin
            field(:score, between(1, 5))
            field(:confidence, between(0.0, 1.0))
        end

        # Valid - within range
        ok, result = try_model_validate(Rating, Dict(:score => 3, :confidence => 0.75))
        @test ok

        # Valid - at boundaries
        ok, result = try_model_validate(Rating, Dict(:score => 1, :confidence => 0.0))
        @test ok

        ok, result = try_model_validate(Rating, Dict(:score => 5, :confidence => 1.0))
        @test ok

        # Invalid - below minimum
        ok, err = try_model_validate(Rating, Dict(:score => 0, :confidence => 0.5))
        @test !ok
        @test any(e -> e.code == :between && e.path == [:score], err.errors)

        # Invalid - above maximum
        ok, err = try_model_validate(Rating, Dict(:score => 6, :confidence => 0.5))
        @test !ok
        @test any(e -> e.code == :between, err.errors)

        # Invalid - confidence out of range
        ok, err = try_model_validate(Rating, Dict(:score => 3, :confidence => 1.5))
        @test !ok
        @test any(e -> e.code == :between && e.path == [:confidence], err.errors)
    end

    @testset "multiple_of() validation" begin
        @model struct Inventory
            quantity::Int
            batch_size::Int
        end

        @rules Inventory begin
            field(:quantity, multiple_of(10))
            field(:batch_size, multiple_of(5))
        end

        # Valid - multiples
        ok, result = try_model_validate(Inventory, Dict(:quantity => 100, :batch_size => 25))
        @test ok

        ok, result = try_model_validate(Inventory, Dict(:quantity => 0, :batch_size => 0))
        @test ok

        ok, result = try_model_validate(Inventory, Dict(:quantity => 50, :batch_size => 10))
        @test ok

        # Invalid - not a multiple of 10
        ok, err = try_model_validate(Inventory, Dict(:quantity => 103, :batch_size => 25))
        @test !ok
        @test any(e -> e.code == :multiple_of && e.path == [:quantity], err.errors)

        # Invalid - not a multiple of 5
        ok, err = try_model_validate(Inventory, Dict(:quantity => 100, :batch_size => 23))
        @test !ok
        @test any(e -> e.code == :multiple_of && e.path == [:batch_size], err.errors)
    end

    @testset "multiple_of() with floats" begin
        @model struct Price
            amount::Float64
        end

        @rules Price begin
            field(:amount, multiple_of(0.25))
        end

        # Valid
        ok, result = try_model_validate(Price, Dict(:amount => 1.0))
        @test ok

        ok, result = try_model_validate(Price, Dict(:amount => 2.5))
        @test ok

        ok, result = try_model_validate(Price, Dict(:amount => 0.75))
        @test ok

        # Invalid
        ok, err = try_model_validate(Price, Dict(:amount => 1.33))
        @test !ok
    end
end

@testset "Combining Advanced Rules" begin
    @model struct CompleteUser
        email::String
        website::String
        age::Int
        score::Int
        status::String
    end

    @rules CompleteUser begin
        field(:email, email())
        field(:website, url())
        field(:age, between(13, 120))
        field(:score, gt(0), lt(1000), multiple_of(10))
        field(:status, choices(["active", "inactive", "banned"]))
    end

    # Valid - all fields pass
    ok, result = try_model_validate(CompleteUser, Dict(
        :email => "user@example.com",
        :website => "https://example.com",
        :age => 25,
        :score => 100,
        :status => "active"
    ))
    @test ok

    # Invalid email
    ok, err = try_model_validate(CompleteUser, Dict(
        :email => "invalid-email",
        :website => "https://example.com",
        :age => 25,
        :score => 100,
        :status => "active"
    ))
    @test !ok
    @test any(e -> e.code == :email, err.errors)

    # Invalid score (not multiple of 10)
    ok, err = try_model_validate(CompleteUser, Dict(
        :email => "user@example.com",
        :website => "https://example.com",
        :age => 25,
        :score => 105,
        :status => "active"
    ))
    @test !ok
    @test any(e -> e.code == :multiple_of, err.errors)

    # Multiple errors
    ok, err = try_model_validate(CompleteUser, Dict(
        :email => "bad-email",
        :website => "not-a-url",
        :age => 150,
        :score => 10000,
        :status => "unknown"
    ))
    @test !ok
    @test length(err.errors) >= 3
end

@testset "Custom error messages for advanced rules" begin
    @model struct CustomMessages
        email::String
        status::String
        score::Int
    end

    @rules CustomMessages begin
        field(:email, email(msg="メールアドレスの形式が正しくありません"))
        field(:status, choices(["active", "inactive"], msg="ステータスは 'active' または 'inactive' である必要があります"))
        field(:score, between(1, 100, msg="スコアは1から100の間である必要があります"))
    end

    # Test custom email message
    ok, err = try_model_validate(CustomMessages, Dict(:email => "invalid", :status => "active", :score => 50))
    @test !ok
    @test any(e -> e.code == :email && occursin("メールアドレス", e.message), err.errors)

    # Test custom choices message
    ok, err = try_model_validate(CustomMessages, Dict(:email => "test@example.com", :status => "unknown", :score => 50))
    @test !ok
    @test any(e -> e.code == :choices && occursin("ステータス", e.message), err.errors)

    # Test custom between message
    ok, err = try_model_validate(CustomMessages, Dict(:email => "test@example.com", :status => "active", :score => 150))
    @test !ok
    @test any(e -> e.code == :between && occursin("スコア", e.message), err.errors)
end
