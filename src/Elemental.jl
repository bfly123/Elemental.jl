module Elemental

using Compat
import Compat.String
using DistributedArrays

import Base: *, \, Ac_mul_B
import Base: convert, copy, copy!, countnz, dot, eltype, fill!, getindex, hcat, inv, length,
    logdet, pointer, print, setindex!, showarray, similar, size
import Base.LinAlg: A_mul_B!, Ac_mul_B!, axpy!, norm, scale!, svd, svdvals, svdvals!

const libEl = abspath(joinpath(dirname(@__FILE__), "..", "deps", "usr", "lib", "libEl"))

include("error.jl")

function Init()
    argc = Cint[0]
    argv = Vector{String}[String[""]]
    ElError(ccall((:ElInitialize, libEl), Cint,
                (Ptr{Cint}, Ptr{Ptr{Ptr{UInt8}}}), argc, pointer(argv)))
    return nothing
end

function Initialized()
    active = Ref(zero(Cint))
    ElError(ccall((:ElInitialized, libEl), Cuint, (Ref{Cint},), active))
    return active[] == 1
end

function Finalize()
    ElError(ccall((:ElFinalize, libEl), Cint, ()))
    return nothing
end

function __init__()
    Init()
    DefaultGrid[] = Grid()
    atexit() do
        Initialized() && Finalize()
    end
end

include("core/types.jl")
include("mpi.jl")
include("core/matrix.jl")
include("core/grid.jl")
include("core/sparsematrix.jl")
include("core/distmatrix.jl")
include("core/distsparsematrix.jl")
include("core/distmultivec.jl")
include("matrices.jl")
include("io.jl")
include("blas_like/level1.jl")
include("blas_like/level2.jl")
include("blas_like/level3.jl")
include("lapack_like/euclidean_min.jl")
include("lapack_like/condense.jl")
include("lapack_like/factor.jl")
include("lapack_like/props.jl")
include("lapack_like/funcs.jl")
include("lapack_like/solve.jl")
include("lapack_like/spectral.jl")
include("optimization/solvers.jl")
include("optimization/models.jl")
include("julia/generic.jl")
include("julia/darray.jl")

end # module
