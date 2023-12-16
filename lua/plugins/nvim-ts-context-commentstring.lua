return {
    "JoosepAlviste/nvim-ts-context-commentstring",
    config = {
        opts = {
            cpp = { __default = "// %s", __multiline = "/* %s */" },
            c = { __default = "// %s", __multiline = "/* %s */" },
        },
    },
}
