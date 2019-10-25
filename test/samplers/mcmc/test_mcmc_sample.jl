# This file is a part of BAT.jl, licensed under the MIT License (MIT).

using BAT
using Test

using Distributed, Random
using ArraysOfArrays, Distributions, PDMats, StatsBase


@testset "mcmc_sample" begin
    mvec = [-0.3, 0.3]
    cmat = [1.0 1.5; 1.5 4.0]
    Σ = @inferred PDMat(cmat)
    mv_dist = MvNormal(mvec, Σ)
    density = @inferred DistributionDensity(mv_dist)
    bounds = @inferred HyperRectBounds([-5, -8], [5, 8], reflective_bounds)
    nsamples_per_chain = 20000
    nchains = 4

    # algorithmMW = @inferred MetropolisHastings() TODO: put back the @inferred
    algorithmMW = MetropolisHastings()
    @test BAT.mcmc_compatible(algorithmMW, GenericProposalDist(mv_dist), NoParamBounds(2))
    # samples, stats = @inferred BAT.mcmc_sample  # TODO: add @inferred again
    samples, stats = BAT.mcmc_sample(
        MCMCSpec(algorithmMW, PosteriorDensity(density, bounds)),
        nsamples_per_chain,
        nchains,
        max_time = Inf,
        granularity = 1
    )

    @test length(samples) == nchains * nsamples_per_chain
    @test samples.params[findmax(samples.log_posterior)[2]] == stats.mode

    cov_samples = cov(flatview(samples.params), FrequencyWeights(samples.weight), 2; corrected=true)
    mean_samples = mean(flatview(samples.params), FrequencyWeights(samples.weight); dims = 2)

    @test isapprox(mean_samples, mvec; rtol = 0.1)
    @test isapprox(cov_samples, cmat; rtol = 0.1)

    algorithmPW = @inferred MetropolisHastings(MHAccRejProbWeights())
    # samples, stats = @inferred BAT.mcmc_sample(
    samples, stats = BAT.mcmc_sample(
        MCMCSpec(algorithmPW, PosteriorDensity(mv_dist, bounds)),
        nsamples_per_chain,
        nchains,
        max_time = Inf,
        granularity = 1
    )

    @test samples.params[findmax(samples.log_posterior)[2]] == stats.mode

    cov_samples = cov(flatview(samples.params), FrequencyWeights(samples.weight), 2; corrected=true)
    mean_samples = mean(flatview(samples.params), FrequencyWeights(samples.weight); dims = 2)

    @test isapprox(mean_samples, mvec; rtol = 0.1)
    @test isapprox(cov_samples, cmat; rtol = 0.1)
end