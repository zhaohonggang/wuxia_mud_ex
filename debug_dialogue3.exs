content = File.read!("test_minimal_world_v2_modified/npc/xiaoer.c")

# Use the module's function
body = Kantele.World.LPCConverter.extract_function_body(content, "accept_object")
IO.puts("Accept body length: #{String.length(body)}")
IO.puts("First 500 chars:")
IO.puts(String.slice(body, 0, 500))

# Test extract_all_strings_with_context
dialogues = Kantele.World.LPCConverter.extract_accept_dialogues(body)
IO.puts("Dialogues: #{inspect(dialogues)}")