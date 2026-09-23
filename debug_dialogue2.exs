content = File.read!("test_minimal_world_v2_modified/npc/xiaoer.c")
body = content

# Extract accept_object body
{:ok, ast} = Kantele.World.LPCConverter.parse_ast(content, "test", "test")
IO.puts("AST accept: #{inspect(ast.accept)}")
IO.puts("AST guard: #{inspect(ast.guard)}")

# Test extract_accept_dialogues directly
dialogues = Kantele.World.LPCConverter.extract_accept_dialogues(ast.accept)
IO.puts("Dialogues: #{inspect(dialogues)}")