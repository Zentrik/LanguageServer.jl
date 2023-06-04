module LanguageServer
using JSON, REPL, CSTParser, JuliaFormatter, SymbolServer, StaticLint
using CSTParser: EXPR, Tokenize.Tokens, Tokenize.Tokens.kind, headof, parentof, valof, to_codeobject
using StaticLint: refof, scopeof, bindingof
using UUIDs
using Base.Docs, Markdown
import JSONRPC
using JSONRPC: Outbound, @dict_readable
import TestItemDetection
using PrecompileTools

@static if VERSION >= v"1.6"
    using TypedSyntax
    using TypedSyntax: gettyp, ndigits_linenumbers, get_function_def, first_byte, type_annotation_mode, catchup, show_annotation, last_byte, is_function_def, children, MaybeTypedSyntaxNode, haschildren, source_line, source_location
    import TypedSyntax: show_annotation, show_src_expr
end

export LanguageServerInstance, runserver

include("URIs2/URIs2.jl")
using .URIs2

JSON.lower(uri::URI) = string(uri)

include("exception_types.jl")
include("protocol/protocol.jl")
include("extensions/extensions.jl")
include("textdocument.jl")
include("document.jl")
include("juliaworkspace.jl")
include("languageserverinstance.jl")
include("multienv.jl")
include("runserver.jl")
include("staticlint.jl")

include("requests/misc.jl")
include("requests/textdocument.jl")
include("requests/features.jl")
include("requests/hover.jl")
include("requests/completions.jl")
include("requests/workspace.jl")
include("requests/actions.jl")
include("requests/init.jl")
include("requests/signatures.jl")
include("requests/highlight.jl")
include("utilities.jl")

@setup_workload begin
    iob = IOBuffer()
    println(iob)
    @compile_workload begin
        runserver(iob)
    end
end
precompile(runserver, ())

end
