@testset "Collection validation" begin
    # Test Vector{String} with each(minlen(3))
    @model struct TaggedPost
        title::String
        tags::Vector{String}
    end

    @rules TaggedPost begin
        field(:title, minlen(1))
        field(:tags, each(minlen(3)))
    end

    # Valid: all tags are at least 3 characters
    ok, result = try_model_validate(TaggedPost, Dict(
        :title => "My Post",
        :tags => ["julia", "programming", "web"]
    ))
    @test ok
    @test result.title == "My Post"
    @test result.tags == ["julia", "programming", "web"]

    # Invalid: second tag is too short
    ok, err = try_model_validate(TaggedPost, Dict(
        :title => "My Post",
        :tags => ["julia", "ab", "web"]
    ))
    @test !ok
    @test any(e -> e.code == :minlen && e.path == [:tags, Symbol("1")], err.errors)

    # Invalid: first tag is too short
    ok, err = try_model_validate(TaggedPost, Dict(
        :title => "My Post",
        :tags => ["ab", "julia", "web"]
    ))
    @test !ok
    @test any(e -> e.code == :minlen && e.path == [:tags, Symbol("0")], err.errors)

    # Invalid: multiple tags too short
    ok, err = try_model_validate(TaggedPost, Dict(
        :title => "My Post",
        :tags => ["ab", "cd", "ef"]
    ))
    @test !ok
    @test count(e -> e.code == :minlen, err.errors) == 3
    @test any(e -> e.path == [:tags, Symbol("0")], err.errors)
    @test any(e -> e.path == [:tags, Symbol("1")], err.errors)
    @test any(e -> e.path == [:tags, Symbol("2")], err.errors)

    # Empty array is valid (no elements to validate)
    ok, result = try_model_validate(TaggedPost, Dict(
        :title => "My Post",
        :tags => String[]
    ))
    @test ok
    @test isempty(result.tags)
end

@testset "Collection validation with numeric constraints" begin
    @model struct ScoreBoard
        name::String
        scores::Vector{Int}
    end

    @rules ScoreBoard begin
        field(:name, minlen(1))
        field(:scores, each(ge(0)), each(le(100)))
    end

    # Valid: all scores in range [0, 100]
    ok, result = try_model_validate(ScoreBoard, Dict(
        :name => "Game1",
        :scores => [10, 50, 90, 100, 0]
    ))
    @test ok
    @test result.scores == [10, 50, 90, 100, 0]

    # Invalid: negative score
    ok, err = try_model_validate(ScoreBoard, Dict(
        :name => "Game1",
        :scores => [10, -5, 90]
    ))
    @test !ok
    @test any(e -> e.code == :ge && e.path == [:scores, Symbol("1")], err.errors)

    # Invalid: score > 100
    ok, err = try_model_validate(ScoreBoard, Dict(
        :name => "Game1",
        :scores => [10, 50, 150]
    ))
    @test !ok
    @test any(e -> e.code == :le && e.path == [:scores, Symbol("2")], err.errors)
end

@testset "Collection length validation" begin
    @model struct Comment
        text::String
        tags::Vector{String}
    end

    @rules Comment begin
        field(:text, minlen(1), maxlen(280))
        field(:tags, minlen(1), maxlen(5))
    end

    # Valid: 3 tags (within [1, 5])
    ok, result = try_model_validate(Comment, Dict(
        :text => "Great post!",
        :tags => ["julia", "awesome", "fast"]
    ))
    @test ok

    # Invalid: no tags (minlen)
    ok, err = try_model_validate(Comment, Dict(
        :text => "Great post!",
        :tags => String[]
    ))
    @test !ok
    @test any(e -> e.code == :minlen && e.path == [:tags], err.errors)

    # Invalid: too many tags (maxlen)
    ok, err = try_model_validate(Comment, Dict(
        :text => "Great post!",
        :tags => ["tag1", "tag2", "tag3", "tag4", "tag5", "tag6"]
    ))
    @test !ok
    @test any(e -> e.code == :maxlen && e.path == [:tags], err.errors)

    # Valid: exactly 1 tag (min boundary)
    ok, result = try_model_validate(Comment, Dict(
        :text => "Great!",
        :tags => ["julia"]
    ))
    @test ok

    # Valid: exactly 5 tags (max boundary)
    ok, result = try_model_validate(Comment, Dict(
        :text => "Great!",
        :tags => ["tag1", "tag2", "tag3", "tag4", "tag5"]
    ))
    @test ok
end

@testset "Collection validation with regex" begin
    @model struct EmailList
        name::String
        emails::Vector{String}
    end

    @rules EmailList begin
        field(:name, minlen(1))
        field(:emails, each(regex(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")))
    end

    # Valid: all emails match pattern
    ok, result = try_model_validate(EmailList, Dict(
        :name => "Team",
        :emails => ["alice@example.com", "bob@test.org"]
    ))
    @test ok

    # Invalid: second email is malformed
    ok, err = try_model_validate(EmailList, Dict(
        :name => "Team",
        :emails => ["alice@example.com", "invalid-email"]
    ))
    @test !ok
    @test any(e -> e.code == :regex && e.path == [:emails, Symbol("1")], err.errors)
end

@testset "Set validation" begin
    @model struct UniqueTagsPost
        title::String
        tags::Set{String}
    end

    @rules UniqueTagsPost begin
        field(:title, minlen(1))
        field(:tags, each(minlen(3)))
    end

    # Valid: all tags in set are at least 3 characters
    ok, result = try_model_validate(UniqueTagsPost, Dict(
        :title => "My Post",
        :tags => Set(["julia", "programming", "web"])
    ))
    @test ok
    @test result.tags == Set(["julia", "programming", "web"])

    # Invalid: one tag is too short
    ok, err = try_model_validate(UniqueTagsPost, Dict(
        :title => "My Post",
        :tags => Set(["julia", "ab", "web"])
    ))
    @test !ok
    @test any(e -> e.code == :minlen, err.errors)
end

@testset "Optional collection fields" begin
    @model Base.@kwdef struct OptionalTagsPost
        title::String
        tags::Union{Nothing,Vector{String}} = nothing
    end

    @rules OptionalTagsPost begin
        field(:title, minlen(1))
        field(:tags, each(minlen(3)))
    end

    # Valid: tags not provided (optional)
    ok, result = try_model_validate(OptionalTagsPost, Dict(
        :title => "My Post"
    ))
    @test ok
    @test result.tags === nothing

    # Valid: tags provided and valid
    ok, result = try_model_validate(OptionalTagsPost, Dict(
        :title => "My Post",
        :tags => ["julia", "programming"]
    ))
    @test ok
    @test result.tags == ["julia", "programming"]

    # Invalid: tags provided but contains invalid element
    ok, err = try_model_validate(OptionalTagsPost, Dict(
        :title => "My Post",
        :tags => ["julia", "ab"]
    ))
    @test !ok
    @test any(e -> e.code == :minlen && e.path == [:tags, Symbol("1")], err.errors)
end

@testset "Collection with default value" begin
    @model Base.@kwdef struct DefaultTagsPost
        title::String
        tags::Vector{String} = ["default"]
    end

    @rules DefaultTagsPost begin
        field(:title, minlen(1))
        field(:tags, each(minlen(3)))
    end

    # Valid: uses default tags
    ok, result = try_model_validate(DefaultTagsPost, Dict(
        :title => "My Post"
    ))
    @test ok
    @test result.tags == ["default"]

    # Valid: overrides default
    ok, result = try_model_validate(DefaultTagsPost, Dict(
        :title => "My Post",
        :tags => ["julia", "programming"]
    ))
    @test ok
    @test result.tags == ["julia", "programming"]
end

@testset "each() on non-collection should error" begin
    @model struct BadEachUsage
        name::String
    end

    @rules BadEachUsage begin
        field(:name, each(minlen(3)))
    end

    # Should report type error for using each() on a string
    ok, err = try_model_validate(BadEachUsage, Dict(
        :name => "test"
    ))
    @test !ok
    @test any(e -> e.code == :type && occursin("collection", e.message), err.errors)
end

@testset "Combining collection rules" begin
    @model struct AdvancedPost
        title::String
        tags::Vector{String}
    end

    @rules AdvancedPost begin
        field(:title, minlen(1))
        field(:tags, minlen(2), maxlen(10), each(minlen(3)), each(maxlen(20)))
    end

    # Valid: meets all constraints
    ok, result = try_model_validate(AdvancedPost, Dict(
        :title => "My Post",
        :tags => ["julia", "programming", "web"]
    ))
    @test ok

    # Invalid: too few tags
    ok, err = try_model_validate(AdvancedPost, Dict(
        :title => "My Post",
        :tags => ["julia"]
    ))
    @test !ok
    @test any(e -> e.code == :minlen && e.path == [:tags], err.errors)

    # Invalid: too many tags
    ok, err = try_model_validate(AdvancedPost, Dict(
        :title => "My Post",
        :tags => ["tag1", "tag2", "tag3", "tag4", "tag5", "tag6",
                  "tag7", "tag8", "tag9", "tag10", "tag11"]
    ))
    @test !ok
    @test any(e -> e.code == :maxlen && e.path == [:tags], err.errors)

    # Invalid: tag too short
    ok, err = try_model_validate(AdvancedPost, Dict(
        :title => "My Post",
        :tags => ["julia", "ab"]
    ))
    @test !ok
    @test any(e -> e.code == :minlen && e.path == [:tags, Symbol("1")], err.errors)

    # Invalid: tag too long
    ok, err = try_model_validate(AdvancedPost, Dict(
        :title => "My Post",
        :tags => ["julia", "this-is-a-very-long-tag-that-exceeds-twenty-characters"]
    ))
    @test !ok
    @test any(e -> e.code == :maxlen && e.path == [:tags, Symbol("1")], err.errors)
end
