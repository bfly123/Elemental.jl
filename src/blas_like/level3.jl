for (elty, relty, ext) in ((:Float32, :Float32, :s),
                           (:Float64, :Float64, :d),
                           (:Complex64, :Float32, :c),
                           (:Complex128, :Float64, :z))

    for (mat, sym) in ((:Matrix, "_"),
                       (:DistMatrix, "Dist_"))

        @eval begin

            function gemm(orientationOfA::Orientation, orientationOfB::Orientation, α::$elty, A::$mat{$elty}, B::$mat{$elty}, β::$elty, C::$mat{$elty})
                ElError(ccall(($(string("ElGemm", sym, ext)), libEl), Cuint,
                    (Orientation, Orientation, $elty, Ptr{Void}, Ptr{Void}, $elty, Ptr{Void}),
                     orientationOfA, orientationOfB, α, A.obj, B.obj, β, C.obj))
                return C
            end

            function trsm(side::LeftOrRight, uplo::UpperOrLower, orientation::Orientation, diag::UnitOrNonUnit, α::$elty, A::$mat{$elty}, B::$mat{$elty})
                ElError(ccall(($(string("ElTrsm", sym, ext)), libEl), Cuint,
                    (LeftOrRight, UpperOrLower, Orientation, UnitOrNonUnit,
                     $elty, Ptr{Void}, Ptr{Void}),
                     side, uplo, orientation, diag,
                     α, A.obj, B.obj))
                return B
            end
        end
    end
end
