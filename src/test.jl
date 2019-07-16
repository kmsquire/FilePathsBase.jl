module TestPaths
    using Test
    using FilePathsBase
    using LinearAlgebra: norm

    # foo, bar, baz, qux, quux, quuz, corge, grault, garply, waldo, fred, plugh, xyzzy, and thud
    #=
    To Test:

    - [X] Construction (T, Path, p"...")
    - [X] show, parse, convert
    - [X] anchor, drive, root
    - [X] hasparent
    - [X] parent
    - [X] parents
    - [X] *, /, join
    - [X] basename
    - [X] filename
    - [X] isempty
    - [X] norm
    - [X] abs?
    - [X] relative?
    - [X] exists
    - [X] real
    - [X] stat/lstat
    - [X] size (could this default to using a FileBuffer?)
    - [X] modified
    - [X] created
    - [X] isdir
    - [X] isfile
    - [X] isexecutable
    - [X] iswritable
    - [X] isreadable
    - [X] cd?
    - [X] mkdir
    - [X] rm
    - [X] read
    - [X] write
    - [X] cp
    - [X] mv
    - [X] readpath
    - [X] walkpath
    - [X] open
    - [ ] chmod
    - [ ] chown
    =#
    """

    root
    |-- foo
    |   |-- baz.txt
    |-- bar
    |   |-- qux
    |       |-- quux.tar.gz
    """
    struct PathSet{P<:AbstractPath}
        root::P
        foo::P
        baz::P
        bar::P
        qux::P
        quux::P
        fred::P
        plugh::Union{P, Nothing}
    end

    function PathSet(root=tmpdir() / "pathset_root"; symlink=false)
        root = abs(root)

        PathSet(
            root,
            root / "foo",
            root / "foo" / "baz.txt",
            root / "bar",
            root / "bar" / "qux",
            root / "bar" / "qux" / "quux.tar.gz",
            root / "fred",
            symlink ? root / "fred" / "plugh" : nothing,
        )
    end

    function initialize(ps::PathSet)
        @info "Initializing $(typeof(ps))"
        mkdir.([ps.foo, ps.qux, ps.fred]; recursive=true)
        write(ps.baz, "Hello World!")
        write(ps.quux, "Hello Again!")

        # If plugh isn't nothing then create a symlink to foo
        if ps.plugh !== nothing
            symlink(ps.foo, ps.plugh)
        end
    end

    function test_constructor(ps::PathSet{P}) where P <: AbstractPath
        @testset "Constructor" begin
            str = string(ps.root)
            @test P(str) == ps.root
        end
    end

    function test_registration(ps::PathSet{P}) where P <: AbstractPath
        @testset "Path constructor" begin
            str = string(ps.root)
            @test FilePathsBase.ispathtype(P, str)
            @test Path(str) == ps.root
            @test p"foo/bar" == Path("foo/bar")
        end
    end

    function test_show(ps::PathSet)
        @testset "show" begin
            str = string(ps.root)
            @test sprint(show, ps.root; context=:compat => true) == "p\"$str\""
            # TODO: Figure out why this is broken.
            @test_broken sprint(show, ps.root; context=:compat => false) == str
        end
    end

    function test_parse(ps::PathSet{P}) where P <: AbstractPath
        @testset "parsing" begin
            str = string(ps.root)
            @test parse(P, str) == ps.root
        end
    end

    function test_convert(ps::PathSet{P}) where P <: AbstractPath
        @testset "convert" begin
            str = string(ps.root)
            @test convert(P, str) == ps.root
            @test convert(String, ps.root) == str
        end
    end

    function test_components(ps::PathSet)
        @testset "components" begin
            str = string(ps.root)
            @test anchor(ps.root) == drive(ps.root) * root(ps.root)
            @test parts(ps.quux)[end-2:end] == ("bar", "qux", "quux.tar.gz")
        end
    end

    function test_parents(ps::PathSet)
        @testset "parents" begin
            @test parent(ps.foo) == ps.root
            @test parent(ps.qux) == ps.bar

            @test hasparent(ps.qux)
            _parents = parents(ps.qux)
            @test _parents[end] == ps.bar
            @test _parents[end - 1] == ps.root
        end
    end

    function test_join(ps::PathSet)
        @testset "join" begin
            @test join(ps.root, "bar") == ps.bar
            @test ps.root / "foo" / "baz.txt" == ps.baz
            @test ps.root / "foobaz.txt" == ps.root / "foo" * "baz.txt"
        end
    end

    function test_basename(ps::PathSet)
        @testset "basename" begin
            @test basename(ps.foo) == "foo"
            @test basename(ps.baz) == "baz.txt"
            @test basename(ps.quux) == "quux.tar.gz"
        end
    end

    function test_filename(ps::PathSet)
        @testset "filename" begin
            @test filename(ps.foo) == "foo"
            @test filename(ps.baz) == "baz"
            @test filename(ps.quux) == "quux"
        end
    end

    function test_extensions(ps::PathSet)
        @testset "extensions" begin
            @test extension(ps.foo) == ""
            @test extension(ps.baz) == "txt"
            @test extension(ps.quux) == "gz"
            @test extensions(ps.foo) == []
            @test extensions(ps.baz) == ["txt"]
            @test extensions(ps.quux) == ["tar", "gz"]
        end
    end

    function test_isempty(ps::PathSet{P}) where P <: AbstractPath
        @testset "isempty" begin
            @test !isempty(ps.foo)
            @test isempty(P())
        end
    end

    function test_norm(ps::PathSet)
        @testset "norm" begin
            @test norm(ps.bar / ".." / "foo") == ps.foo
            @test norm(ps.bar / ".") == ps.bar
        end
    end

    function test_real(ps::PathSet)
        @testset "real" begin
            @test_broken real(ps.bar / ".." / "foo") == norm(ps.bar / ".." / "foo")
            @test_broken real(ps.bar / ".") == norm(ps.bar / ".")

            if ps.plugh !== nothing
                @test_broken real(ps.plugh) == ps.foo
            end
        end
    end

    function test_relative(ps::PathSet)
        @testset "relative" begin
            @test parts(relative(ps.foo, ps.qux)) == ("..", "..", "foo")
        end
    end

    function test_abs(ps::PathSet)
        @testset "abs" begin
            @test isabs(ps.root) || isabs(abs(ps.root))
        end
    end

    function test_isdir(ps::PathSet)
        @testset "isdir" begin
            @test isdir(ps.foo)
            @test !isdir(ps.baz)
        end
    end

    function test_isfile(ps::PathSet)
        @testset "isfile" begin
            @test isfile(ps.baz)
            @test !isfile(ps.foo)
        end
    end

    function test_stat(ps::PathSet)
        @testset "stat" begin
            s = stat(ps.root)
            fields = fieldnames(typeof(s))

            @test :size in fields
            @test :ctime in fields
            @test :mtime in fields
            @test :user in fields
            @test :mode in fields

            if ps.plugh !== nothing
                @test lstat(ps.plugh) != stat(ps.plugh)
            end
        end
    end

    function test_size(ps::PathSet)
        @testset "size" begin
            @test size(ps.baz) > 0
        end
    end

    function test_modified(ps::PathSet)
        @testset "modified" begin
            @test isa(modified(ps.baz), Dates.AbstractDateTime)
            @test modified(ps.baz) >= modified(ps.root)
        end
    end

    function test_created(ps::PathSet)
        @testset "created" begin
            @test isa(created(ps.baz), Dates.AbstractDateTime)
            @test created(ps.baz) >= created(ps.root)
        end
    end

    function test_isexecutable(ps::PathSet{P}) where P <: AbstractPath
        @testset "isexecutable" begin
            # I'm not entirely sure how to test this generally
            @test !isexecutable(ps.baz)

            # Directories should be executable for system paths
            if P <: SystemPath
                @test isexecutable(ps.foo)
            end
        end
    end

    function test_isreadable(ps::PathSet)
        @testset "isreadable" begin
            # Our test files should be readable by default
            @test isreadable(ps.baz)
            @test isreadable(ps.quux)

            # Our test directories should also be readable by default
            @test isreadable(ps.foo)
            @test isreadable(ps.qux)
        end
    end

    function test_iswritable(ps::PathSet)
        @testset "iswritable" begin
            # Our test files should be writable by default
            @test iswritable(ps.baz)
            @test iswritable(ps.quux)

            # Our test directories should also be writable by default
            @test iswritable(ps.foo)
            @test iswritable(ps.qux)
        end
    end

    function test_cd(ps::PathSet{P}) where P <: AbstractPath
        if P <: SystemPath
            @testset "cd" begin
                init_path = cwd()

                cd(ps.foo) do
                    @test cwd() != real(init_path)
                    @test cwd() == real(ps.foo)
                end

                @test cwd() == real(init_path)

                cd(ps.qux)
                @test cwd() != real(init_path)
                @test cwd() == real(ps.qux)
                cd(init_path)
                @test cwd() == real(init_path)
            end
        end
    end

    function test_readpath(ps::PathSet)
        @testset "readpath" begin
            @test readdir(ps.root) == ["bar", "foo", "fred"]
            @test readdir(ps.qux) == ["quux.tar.gz"]
            @test readpath(ps.root) == [ps.bar, ps.foo, ps.fred]
            @test readpath(ps.qux) == [ps.quux]
        end
    end

    function test_walkpath(ps::PathSet)
        @testset "walkpath" begin
            topdown = [ps.bar, ps.qux, ps.quux, ps.foo, ps.baz]
            bottomup = [ps.quux, ps.qux, ps.bar, ps.baz, ps.foo]

            if ps.plugh == nothing
                push!(topdown, ps.fred)
                push!(bottomup, ps.fred)
            else
                append!(topdown, [ps.fred, ps.plugh])
                append!(bottomup, [ps.plugh, ps.fred])
            end

            @test collect(walkpath(ps.root; topdown=true)) == topdown
            @test collect(walkpath(ps.root; topdown=false)) == bottomup
        end
    end

    function test_read(ps::PathSet)
        @testset "read" begin
            @test read(ps.baz, String) == "Hello World!"
            open(ps.quux, "r") do io
                @test read(io, String) == "Hello Again!"
            end
        end
    end

    function test_write(ps::PathSet)
        @testset "write" begin
            write(ps.baz, "Goodbye World!")
            @test read(ps.baz, String) == "Goodbye World!"

            @testset "truncate" begin
                open(ps.quux, "w") do io
                    write(io, "Hello?")
                end
                @test read(ps.quux, String) == "Hello?"
            end

            @testset "append" begin
                open(ps.quux, "a") do io
                    write(io, " Did you need something?")
                end
                @test read(ps.quux, String) == "Hello? Did you need something?"
            end

            @testset "read/write" begin
                open(ps.quux, "w+") do io
                    write(io, "Goodnight!")
                    seekstart(io)
                    @test read(io, String) == "Goodnight!"
                end

                open(ps.quux, "a+") do io
                    write(io, " Zzzz")
                    seekstart(io)
                    @test read(io, String) == "Goodnight! Zzzz"
                end
            end
        end
    end

    function test_mkdir(ps::PathSet)
        @testset "mkdir" begin
            garply = ps.root / "corge" / "grault" / "garply"
            mkdir(garply; recursive=true, exist_ok=true)
            @test exists(garply)
            rm(ps.root / "corge"; recursive=true)
            @test !exists(garply)
        end
    end

    function test_cp(ps::PathSet)
        @testset "cp" begin
            cp(ps.foo, ps.qux / "foo"; force=true)
            @test exists(ps.qux / "foo" / "baz.txt")
            rm(ps.qux / "foo"; recursive=true)
        end
    end

    function test_mv(ps::PathSet)
        @testset "mv" begin
            garply = ps.root / "corge" / "grault" / "garply"
            mkdir(garply; recursive=true, exist_ok=true)
            @test exists(garply)
            mv(ps.root / "corge", ps.foo / "corge"; force=true)
            @test !exists(garply)
            @test exists(ps.foo / "corge" / "grault" / "garply")
            rm(ps.foo / "corge"; recursive=true)
        end
    end

    TESTALL = [
        test_constructor,
        test_registration,
        test_show,
        test_parse,
        test_convert,
        test_components,
        test_parents,
        test_join,
        test_basename,
        test_filename,
        test_extensions,
        test_isempty,
        test_norm,
        test_real,
        test_relative,
        test_abs,
        test_isdir,
        test_isfile,
        test_stat,
        test_size,
        test_isexecutable,
        test_isreadable,
        test_iswritable,
        test_cd,
        test_readpath,
        test_walkpath,
        test_read,
        test_write,
        test_mkdir,
        test_cp,
        test_mv,
    ]

    function test(ps::PathSet, test_sets=TESTALL)
        try
            initialize(ps)

            for ts in test_sets
                ts(ps)
            end
        finally
            rm(ps.root; recursive=true, force=true)
        end
    end
end