# What is the fabric framework?

Fabric is a CLI tool created to address the integration of AI applications, not the capabilities. [Daniel Miessler (creator)](https://www.youtube.com/watch?v=wPEyyigh10g) and [Network Chuck](https://www.youtube.com/watch?v=UbDyjIIGaxQ) cover this well and it's worth your time to check them out. If you do nothing else with Fabric, [check out the patterns in the repo](https://github.com/danielmiessler/fabric/tree/main/patterns) for your own prompt ideas. Follow the new installation steps though, the framework was rewritten in go since these videos premiered.

Prerequisites 
- if you don't already have an LLM to interrogate, [install Ollama first](/ollama_basics/), you'll need it or a remote service to use fabric.
- Fabric needs models in the 7B to 34B parameter range. If you don't have the ability locally to run models of this size, sign up for API access to one of the fabric-supported services to get desired results.
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