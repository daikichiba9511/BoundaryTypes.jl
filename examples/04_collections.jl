# Collection Validation Example
#
# This example demonstrates validation of arrays, vectors, and sets
# using the each() combinator and collection-specific rules.

using BoundaryTypes

# 1. Basic Collection Validation
println("=" ^ 80)
println("Basic Collection Validation")
println("=" ^ 80)

@model struct TaggedPost
    title::String
    tags::Vector{String}
end

@rules TaggedPost begin
    field(:title, minlen(1), maxlen(200))

    # Validate collection size and each element
    field(:tags,
          minlen(1),           # At least 1 tag
          maxlen(10),          # At most 10 tags
          each(minlen(2)))     # Each tag at least 2 characters
end

# Valid tagged post
valid_post = Dict(
    :title => "Introduction to Julia",
    :tags => ["julia", "programming", "tutorial"]
)

post = model_validate(TaggedPost, valid_post)
println("✓ Post created: $(post.title)")
println("  Tags: $(join(post.tags, ", "))")
println()

# Invalid: tag too short
invalid_tag = Dict(
    :title => "Another Post",
    :tags => ["julia", "x"]  # "x" is too short
)

ok, result = try_model_validate(TaggedPost, invalid_tag)
if !ok
    println("✗ Invalid tag:")
    for err in result.errors
        # Error path includes array index: [:tags, Symbol("1")]
        println("  - $(join(err.path, ".")): $(err.message)")
    end
end
println()

# 2. Numeric Collection Validation
println("=" ^ 80)
println("Numeric Collection Validation")
println("=" ^ 80)

@model struct TestScores
    student_name::String
    scores::Vector{Int}
end

@rules TestScores begin
    field(:student_name, minlen(1))

    # All scores must be between 0 and 100
    field(:scores,
          minlen(1),              # At least one score
          each(ge(0)),            # Each score >= 0
          each(le(100)))          # Each score <= 100
end

# Valid scores
valid_scores = Dict(
    :student_name => "Alice",
    :scores => [85, 92, 88, 95]
)

scores = model_validate(TestScores, valid_scores)
println("✓ Scores recorded for: $(scores.student_name)")
println("  Scores: $(scores.scores)")
println("  Average: $(round(sum(scores.scores) / length(scores.scores), digits=2))")
println()

# Invalid: score out of range
invalid_score = Dict(
    :student_name => "Bob",
    :scores => [85, 110, 88]  # 110 is > 100
)

ok, result = try_model_validate(TestScores, invalid_score)
if !ok
    println("✗ Invalid score:")
    for err in result.errors
        println("  - $(join(err.path, ".")): $(err.message)")
    end
end
println()

# 3. Multiple Collection Constraints
println("=" ^ 80)
println("Multiple Collection Constraints")
println("=" ^ 80)

@model struct Survey
    question::String
    allowed_ages::Vector{Int}
    responses::Vector{String}
end

@rules Survey begin
    field(:question, minlen(5))

    # Ages: must be multiples of 5, between 0 and 100
    field(:allowed_ages,
          minlen(1),
          each(ge(0)),
          each(le(100)),
          each(multiple_of(5)))

    # Responses: 10-500 characters each
    field(:responses,
          each(minlen(10)),
          each(maxlen(500)))
end

# Valid survey
valid_survey = Dict(
    :question => "What is your programming experience?",
    :allowed_ages => [20, 25, 30, 35, 40],
    :responses => [
        "I have been programming for 5 years.",
        "Started with Python, now learning Julia.",
        "Professional developer with 10+ years experience."
    ]
)

survey = model_validate(Survey, valid_survey)
println("✓ Survey created: $(survey.question)")
println("  Target age groups: $(survey.allowed_ages)")
println("  Responses collected: $(length(survey.responses))")
println()

# Invalid: age not multiple of 5
invalid_ages = Dict(
    :question => "What is your favorite color?",
    :allowed_ages => [20, 23, 30],  # 23 is not multiple of 5
    :responses => ["I like blue color."]
)

ok, result = try_model_validate(Survey, invalid_ages)
if !ok
    println("✗ Invalid age value:")
    for err in result.errors
        println("  - $(join(err.path, ".")): $(err.message)")
    end
end
println()

# 4. Set Validation
println("=" ^ 80)
println("Set Validation")
println("=" ^ 80)

@model struct UniqueSkills
    username::String
    skills::Set{String}
end

@rules UniqueSkills begin
    field(:username, minlen(1))
    field(:skills,
          minlen(1),           # At least 1 skill
          each(minlen(2)))     # Each skill at least 2 characters
end

# Valid skills set
valid_skills = Dict(
    :username => "developer123",
    :skills => Set(["Julia", "Python", "Rust", "Go"])
)

user_skills = model_validate(UniqueSkills, valid_skills)
println("✓ Skills registered for: $(user_skills.username)")
println("  Skills: $(join(user_skills.skills, ", "))")
println()

# 5. Optional Collections
println("=" ^ 80)
println("Optional Collection Validation")
println("=" ^ 80)

@model Base.@kwdef struct Article
    title::String
    content::String
    tags::Union{Nothing,Vector{String}} = nothing  # Optional collection
end

@rules Article begin
    field(:title, minlen(1))
    field(:content, minlen(10))
    # Tags validated only if provided
    field(:tags, each(minlen(2)))
end

# Without tags
article_no_tags = Dict(
    :title => "My Article",
    :content => "This is the article content."
)

article1 = model_validate(Article, article_no_tags)
println("✓ Article created: $(article1.title)")
println("  Tags: $(isnothing(article1.tags) ? "None" : join(article1.tags, ", "))")
println()

# With tags
article_with_tags = Dict(
    :title => "Another Article",
    :content => "More content here.",
    :tags => ["tech", "julia"]
)

article2 = model_validate(Article, article_with_tags)
println("✓ Article created: $(article2.title)")
println("  Tags: $(join(article2.tags, ", "))")
println()

# 6. Complex Collection Example
println("=" ^ 80)
println("Complex Collection Validation")
println("=" ^ 80)

@model struct EmailCampaign
    subject::String
    recipients::Vector{String}  # Email addresses
    priority_levels::Vector{Int}
end

@rules EmailCampaign begin
    field(:subject, minlen(5), maxlen(100))

    # All recipients must be valid email addresses
    field(:recipients,
          minlen(1),
          maxlen(1000),
          each(email()))

    # Priority levels: 1-5, one per recipient
    field(:priority_levels,
          each(ge(1)),
          each(le(5)))
end

# Valid campaign
valid_campaign = Dict(
    :subject => "Weekly Newsletter - Julia Updates",
    :recipients => [
        "alice@example.com",
        "bob@example.com",
        "charlie@example.com"
    ],
    :priority_levels => [2, 1, 3]
)

campaign = model_validate(EmailCampaign, valid_campaign)
println("✓ Campaign created: $(campaign.subject)")
println("  Recipients: $(length(campaign.recipients))")
println()

# Invalid: bad email in collection
invalid_recipients = Dict(
    :subject => "Important Update",
    :recipients => [
        "alice@example.com",
        "not-an-email",  # Invalid email
        "bob@example.com"
    ],
    :priority_levels => [1, 2, 1]
)

ok, result = try_model_validate(EmailCampaign, invalid_recipients)
if !ok
    println("✗ Invalid recipient email:")
    for err in result.errors
        println("  - $(join(err.path, ".")): $(err.message)")
    end
end
println()

println("=" ^ 80)
println("Tip: Use each() to validate individual collection elements!")
println("=" ^ 80)
