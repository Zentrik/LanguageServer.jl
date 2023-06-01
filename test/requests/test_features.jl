@testitem "signatures" begin
    include("../test_shared_server.jl")

    doc = settestdoc("""
    rand()
    Base.rand()
    func(arg) = 1
    func()
    struct T
        a
        b
    end
    T()
    struct S{R}
        a
        S() = new(1)
    end
    using Base:argtail
    argtail()
    S{R}()
    """)
    @test !isempty(sig_test(0, 5).signatures)
    @test !isempty(sig_test(1, 10).signatures)
    @test !isempty(sig_test(3, 5).signatures)
    @test !isempty(sig_test(8, 2).signatures)
    @test_broken !isempty(sig_test(15, 5).signatures)

    let sigs = LanguageServer.SignatureInformation[]
        LanguageServer.get_signatures(doc.cst[3].meta.binding, doc.cst.meta.scope, sigs, LanguageServer.getenv(server))
        @test length(sigs) == 1
    end
    let sigs = LanguageServer.SignatureInformation[]
        LanguageServer.get_signatures(doc.cst[5].meta.binding, doc.cst.meta.scope, sigs, LanguageServer.getenv(server))
        @test length(sigs) == 1
    end
    let sigs = LanguageServer.SignatureInformation[]
        LanguageServer.get_signatures(doc.cst[1][1].meta.ref, doc.cst.meta.scope, sigs, LanguageServer.getenv(server))
        @test length(sigs) > 0
    end
    let sigs = LanguageServer.SignatureInformation[]
        LanguageServer.get_signatures(doc.cst[7].meta.binding, doc.cst.meta.scope, sigs, LanguageServer.getenv(server))
        @test length(sigs) == 1
    end
    let sigs = LanguageServer.SignatureInformation[]
        LanguageServer.get_signatures(doc.cst[9][1].meta.ref, doc.cst.meta.scope, sigs, LanguageServer.getenv(server))
        @test length(sigs) == 1
    end
end

@testitem "definitions" begin
    include("../test_shared_server.jl")

    settestdoc("""
    rand()
    func(arg) = 1
    func()
    Float64
    """)
    # @test !isempty(def_test(0, 3))
    @test !isempty(def_test(2, 3))
    @test !isempty(def_test(3, 3))
end

@testitem "references" begin
    include("../test_shared_server.jl")

    settestdoc("""
    func(arg) = 1
    func()
    """)
    @test length(ref_test(1, 2)) == 2
end

@testitem "rename" begin
    include("../test_shared_server.jl")

    settestdoc("""
    func(arg) = 1
    func()
    """)
    @test length(rename_test(0, 2).documentChanges[1].edits) == 2
end

@testitem "get_file_loc" begin
    include("../test_shared_server.jl")

    doc = settestdoc("""
    func(arg) = 1
    func()
    """)
    @test LanguageServer.get_file_loc(doc.cst.args[2].args[1]) == (doc, 14)
end

@testitem "doc symbols" begin
    include("../test_shared_server.jl")
    
    doc = settestdoc("""
    a = 1
    b = 2
    function func() end
    function (::Bar)() end
    function (::Type{Foo})() end
    """)
    @test all(item.name in ("a", "b", "func", "::Bar", "::Type{Foo}") for item in LanguageServer.textDocument_documentSymbol_request(LanguageServer.DocumentSymbolParams(LanguageServer.TextDocumentIdentifier(uri"untitled:testdoc"), missing, missing), server, server.jr_endpoint))
end

@testitem "range formatting" begin
    include("../test_shared_server.jl")

    doc = settestdoc("""
    map([A,B,C]) do x
    if x<0 && iseven(x)
    return 0
    elseif x==0
    return 1
    else
    return x
    end
    end
    """)
    @test range_formatting_test(0, 0, 8, 0)[1].newText == """
    map([A, B, C]) do x
        if x < 0 && iseven(x)
            return 0
        elseif x == 0
            return 1
        else
            return x
        end
    end
    """

    doc = settestdoc("""
    map([A,B,C]) do x
    if x<0 && iseven(x)
    return 0
    elseif x==0
    return 1
    else
    return x
    end
    end
    """)
    @test range_formatting_test(2, 0, 2, 0)[1].newText == "        return 0\n"

    doc = settestdoc("""
    function add(a,b) a+b end
    function sub(a,b) a-b end
    function mul(a,b) a*b end
    """)
    @test range_formatting_test(1, 0, 1, 0)[1].newText == """
    function sub(a, b)
        a - b
    end
    """

    doc = settestdoc("""
    function sub(a, b)
        a - b
    end
    """)
    @test range_formatting_test(0, 0, 2, 0) == LanguageServer.TextEdit[]

    # \r\n line endings
    doc = settestdoc("function foo(a,  b)\r\na - b\r\n end\r\n")
    @test range_formatting_test(0, 0, 2, 0)[1].newText == "function foo(a, b)\r\n    a - b\r\nend\r\n"

    # no trailing newline
    doc = settestdoc("function foo(a,  b)\na - b\n end")
    @test range_formatting_test(0, 0, 2, 0)[1].newText == "function foo(a, b)\n    a - b\nend"
end

@testset "inlay hints" begin
    doc = settestdoc("""
    a = 1
    b = 2.0
    f(xx) = xx
    f(xxx, yyy) = xx + yy
    f(2)
    f(2, 3)
    f(2, f(3))
    f(2, 3) # this request is outside of the requested range
    """)
    function hints_with_mode(mode)
        old_mode = server.inlay_hint_mode
        server.inlay_hint_mode = mode
        hints = LanguageServer.textDocument_inlayHint_request(
            LanguageServer.InlayHintParams(
                LanguageServer.TextDocumentIdentifier(uri"untitled:testdoc"),
                LanguageServer.Range(LanguageServer.Position(0, 0), LanguageServer.Position(7, 0)),
                missing
            ),
            server,
            server.jr_endpoint
        )
        server.inlay_hint_mode = old_mode
        return hints
    end
    @test hints_with_mode(:none) === nothing
    @test map(x -> x.label, hints_with_mode(:literals)) == [
        string("::", Int),
        "::Float64",
        "xx:",
        "xxx:",
        "yyy:",
        "xxx:",
        "xx:"
    ]
    @test map(x -> x.label, hints_with_mode(:all)) == [
        string("::", Int),
        "::Float64",
        "xx:",
        "xxx:",
        "yyy:",
        "xxx:",
        "yyy:", # not a literal
        "xx:"
    ]
    map(x -> x.position, hints_with_mode(:all)) == [
        LanguageServer.Position(0, 1),
        LanguageServer.Position(1, 1),
        LanguageServer.Position(2, 4),
        LanguageServer.Position(4, 2),
        LanguageServer.Position(5, 2),
        LanguageServer.Position(5, 5),
        LanguageServer.Position(6, 2),
        LanguageServer.Position(6, 5),
        LanguageServer.Position(6, 7),
    ]
end