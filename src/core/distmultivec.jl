type DistMultiVec{T} <: ElementalMatrix{T}
    obj::Ptr{Void}
end

for (elty, ext) in ((:ElInt, :i),
                    (:Float32, :s),
                    (:Float64, :d),
                    (:Complex64, :c),
                    (:Complex128, :z))
    @eval begin

        # destructor to be used in finalizer. Don't call explicitly
        function destroy(A::DistMultiVec{$elty})
            ElError(ccall(($(string("ElDistMultiVecDestroy_", ext)), libEl), Cuint,
                (Ptr{Void},), A.obj))
            return nothing
        end

        function DistMultiVec(::Type{$elty}, cm::ElComm = CommWorld)
            obj = Ref{Ptr{Void}}(C_NULL)
            ElError(ccall(($(string("ElDistMultiVecCreate_", ext)), libEl), Cuint,
                (Ref{Ptr{Void}}, ElComm),
                obj, cm))
            A = DistMultiVec{$elty}(obj[])
            finalizer(A, destroy)
            return A
        end

        function comm(A::DistMultiVec{$elty})
            cm = Ref{ElComm}()
            ElError(ccall(($(string("ElDistMultiVecComm_", ext)), libEl), Cuint,
                (Ptr{Void}, Ref{ElComm}),
                A.obj, cm))
            return cm[]
        end

        function get(x::DistMultiVec{$elty}, i::Integer = size(x, 1), j::Integer = 1)
            v = Ref{$elty}()
            ElError(ccall(($(string("ElDistMultiVecGet_", ext)), libEl), Cuint,
                (Ptr{Void}, ElInt, ElInt, Ref{$elty}),
                x.obj, i - 1, j - 1, v))
            return v[]
        end

        function getLocal(A::DistMultiVec{$elty}, i::Integer, j::Integer)
            rv = Ref{$elty}(0)
            ElError(ccall(($(string("ElDistMultiVecGetLocal_", ext)), libEl), Cuint,
                (Ptr{Void}, ElInt, ElInt, Ref{$elty}),
                A.obj, i - 1, j - 1, rv))
            return rv[]
        end

        function globalRow(A::DistMultiVec{$elty}, i::Integer)
            rv = Ref{ElInt}(0)
            ElError(ccall(($(string("ElDistMultiVecGlobalRow_", ext)), libEl), Cuint,
                (Ptr{Void}, ElInt, Ref{ElInt}),
                A.obj, i - 1, rv))
            return rv[] + 1
        end

        function height(x::DistMultiVec{$elty})
            i = Ref{ElInt}()
            ElError(ccall(($(string("ElDistMultiVecHeight_", ext)), libEl), Cuint,
                (Ptr{Void}, Ref{ElInt}),
                x.obj, i))
            return i[]
        end

        function localHeight(A::DistMultiVec{$elty})
            rv = Ref{ElInt}(0)
            ElError(ccall(($(string("ElDistMultiVecLocalHeight_", ext)), libEl), Cuint,
                (Ptr{Void}, Ref{ElInt}),
                A.obj, rv))
            return rv[]
        end

        function processQueues(A::DistMultiVec{$elty})
            ElError(ccall(($(string("ElDistMultiVecProcessQueues_", ext)), libEl), Cuint,
                (Ptr{Void},), A.obj))
          return nothing
        end

        function queueUpdate(A::DistMultiVec{$elty}, i::Integer, j::Integer, value::$elty)
            ElError(ccall(($(string("ElDistMultiVecQueueUpdate_", ext)), libEl), Cuint,
              (Ptr{Void}, ElInt, ElInt, $elty),
              A.obj, i - 1, j - 1, value))
            return nothing
        end

        function reserve(A::DistMultiVec{$elty}, numEntries::Integer)
            ElError(ccall(($(string("ElDistMultiVecReserve_", ext)), libEl), Cuint,
              (Ptr{Void}, ElInt),
              A.obj, numEntries))
            return nothing
        end

        function resize!(A::DistMultiVec{$elty}, m::Integer, n::Integer = 1) # to mimic vector behavior
            ElError(ccall(($(string("ElDistMultiVecResize_", ext)), libEl), Cuint,
              (Ptr{Void}, ElInt, ElInt),
              A.obj, ElInt(m), ElInt(n)))
            return A
        end

        function width(x::DistMultiVec{$elty})
            i = Ref{ElInt}()
            ElError(ccall(($(string("ElDistMultiVecWidth_", ext)), libEl), Cuint,
                (Ptr{Void}, Ref{ElInt}),
                x.obj, i))
            return i[]
        end
    end
end

#########################
### Julia convenience ###
#########################

getindex(x::DistMultiVec, i, j) = get(x, i, j)

function similar{T}(::DistMultiVec, ::Type{T}, sz::Dims, cm::ElComm = CommWorld)
    A = DistMultiVec(T, cm)
    resize!(A, sz...)
    return A
end

# FixMe! Should this one handle vectors of matrices?
function hcat{T}(x::Vector{DistMultiVec{T}})
    l    = length(x)
    if l == 0
        throw(ArgumentError("cannot flatten empty vector"))
    else
        x1   = x[1]
        m, n = size(x1, 1), size(x1, 2)
        if n != 1
            throw(ArgumentError("elements has to be vectors, i.e. the second dimension has to have size one"))
        end
        A    = DistMultiVec(T)
        zeros!(A, m, l*n)
        for j = 1:l
            xj = x[j]
            for k = 1:width(xj)
                for i = 1:localHeight(xj)
                    xji = getLocal(xj, i, 1)
                    queueUpdate(A, globalRow(xj, i), j, xji)
                end
            end
        end
        processQueues(A)
        return A
    end
end
