export NullSearch

"""
    Search(p::DSProblem{T})::IterationOutcome  where T

Generate search points and call evaluate on them.
"""
function Search(p::DSProblem{T})::IterationOutcome  where T
    p.status.search_time_total += @elapsed points = GenerateSearchPoints(p, p.config.search)
    p.full_output && OutputSearchStep(p, points)
    p.status.directions = nothing
    return EvaluatePoint!(p, points)
end


"""
    GenerateSearchPoints(p::DSProblem{T})::Vector{Vector{T}} where T

Calls `GenerateSearchPoints` for the search step within `p`.
"""
(GenerateSearchPoints(p::DSProblem{T})::Vector{Vector{T}}) where T = GenerateSearchPoints(p, p.config.search)


################################################################
# Null search that alows the search step to be skipped
################################################################

"""
    NullSearch()

Return no trial points for a search stage (ie, skips the search stage from running)
"""
struct NullSearch <: AbstractSearch end

"""
    GenerateSearchPoints(p::DSProblem, ::NullSearch)

Search method that returns an empty vector.

Use when no search method is desired.
"""
(GenerateSearchPoints(p::DSProblem{T}, ::NullSearch)::Vector{Vector{T}}) where T = Vector{T}[]

