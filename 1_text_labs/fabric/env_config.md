# Configuring fabric

1. [Install the framework](https://github.com/danielmiessler/fabric?tab=readme-ov-file#Installation). Make sure to test that the fabric command will run and set environment variables if needed
2. Run the setup by typing `fabric --setup`.
   1. Select 2 for Ollama and enter `http://localhost:11434` as the URL. Add additional vendors as appropriate to your environment.
   2. Once done selecting, leave the prompt blank and hit return.
   3. Make sure you have some models available by typing `fabric -L`. I have OpenAI and Ollama, so my current list (abridged for brevity) is:
<pre>Ollama

	[1]	gemma3:1b
	[2]	gemma3:4b
	[3]	gemma3:latest
	[4]	llama3.3:latest

OpenAI

	[5]	gpt-4.1-nano-2025-04-14
	[6]	gpt-4o-audio-preview-2024-12-17
	[7]	dall-e-3
	[8]	text-embedding-3-large</pre>

# Conclusion

You now have a working fabric framework, let's do something with it by [using a couple existing patterns](/fabric/existing_patterns.md). 