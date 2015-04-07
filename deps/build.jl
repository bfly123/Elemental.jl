const Git = Base.Git

depdir = dirname(@__FILE__)

if !isdir(joinpath(depdir, "src"))
    mkdir(joinpath(depdir, "src"))
end
srcdir = joinpath(depdir, "src", "Elemental")

if !isdir(joinpath(depdir, "usr"))
    mkdir(joinpath(depdir, "usr"))
end
prefix = joinpath(depdir, "usr")

if !isdir(srcdir)
    Git.run(`clone -- https://github.com/elemental/Elemental.git $srcdir`)
end

cd(srcdir) do
    Git.run(`submodule init external/metis`)
    Git.run(`submodule update external/metis`)
    Git.run(`submodule init external/kiss_fft`)
    Git.run(`submodule update external/kiss_fft`)
end

Base.check_blas()
blas = Base.blas_vendor()

cd(srcdir) do
    builddir = joinpath(depdir, "builds")
    if isdir(builddir)
        rm(builddir, recursive=true)
    end
    mkdir(builddir)

    mathlib = Libdl.dlpath(BLAS.libblas)
    blas64 = LinAlg.USE_BLAS64 ? "ON" : "OFF"

    if blas === :openblas || blas === :openblas64
        blas_suffix = blas === :openblas64 ?  "_64_" : ""
    else
        error("Only building Elemental with OpenBLAS is supported at the moment")
    end

    cd(builddir) do
        run(`cmake -D CMAKE_INSTALL_PREFIX=$prefix
                   -D INSTALL_PYTHON_PACKAGE=OFF
                   -D PYTHON_EXECUTABLE=“”
                   -D PYTHON_SITE_PACKAGES=“”
                   -D EL_USE_64BIT_INTS=$blas64
                   -D MATH_LIBS=$mathlib
                   -D EL_BLAS_SUFFIX=$blas_suffix
                   -D EL_LAPACK_SUFFIX=$blas_suffix
                   $srcdir`)
        run(`make -j $CPU_CORES`)
        run(`make install`)
    end
end