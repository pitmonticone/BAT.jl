# This file is a part of BAT.jl, licensed under the MIT License (MIT).


"""
    struct MCMCMultiCycleBurnin <: MCMCBurninAlgorithm

A multi-cycle MCMC burn-in algorithm.

Constructors:

* ```$(FUNCTIONNAME)(; fields...)```

Fields:

$(TYPEDFIELDS)
"""
@with_kw struct MCMCMultiCycleBurnin <: MCMCBurninAlgorithm
    nsteps_per_cycle::Int64 = 10000
    max_ncycles::Int = 30
end

export MCMCMultiCycleBurnin


function mcmc_burnin!(
    outputs::Union{AbstractVector{<:DensitySampleVector},Nothing},
    tuners::AbstractVector{<:AbstractMCMCTunerInstance},
    chains::AbstractVector{<:MCMCIterator},
    burnin_alg::MCMCMultiCycleBurnin,
    convergence_test::MCMCConvergenceTest,
    strict_mode::Bool,
    nonzero_weights::Bool,
    callback::Function
)
    @info "Begin tuning of $(length(tuners)) MCMC chain(s)."

    nchains = length(chains)

    cycles = zero(Int)
    successful = false
    while !successful && cycles < burnin_alg.max_ncycles
        cycles += 1

        new_outputs = DensitySampleVector.(chains)

        mcmc_iterate!(
            new_outputs,
            chains,
            max_nsteps = burnin_alg.nsteps_per_cycle,
            nonzero_weights = nonzero_weights,
            callback = callback
        )

        tuning_update!.(tuners, chains, new_outputs)
        isnothing(outputs) || append!.(outputs, new_outputs)

        ct_result = check_convergence!(convergence_test, chains, new_outputs)

        ntuned = count(c -> c.info.tuned, chains)
        nconverged = count(c -> c.info.converged, chains)
        successful = (ntuned == nconverged == nchains)

        callback(Val(:mcmc_burnin), tuners, chains)

        @info "MCMC Tuning cycle $cycles finished, $nchains chains, $ntuned tuned, $nconverged converged."

        next_cycle!.(chains)
    end

    if successful
        @info "MCMC tuning of $nchains chains successful after $cycles cycle(s)."
    else
        msg = "MCMC tuning of $nchains chains aborted after $cycles cycle(s)."
        if strict_mode
            throw(ErrorException(msg))
        else
            @warn msg
        end
    end

    successful
end
