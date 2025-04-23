![Static Badge](https://img.shields.io/badge/Author-f5--rahm-blue?link=https%3A%2F%2Fgithub.com%2Ff5-rahm)

# What is the fabric framework?

Fabric is a CLI tool created to address the integration of AI applications, not the capabilities. [Daniel Miessler (creator)](https://www.youtube.com/watch?v=wPEyyigh10g) and [Network Chuck](https://www.youtube.com/watch?v=UbDyjIIGaxQ) cover this well and it's worth your time to check them out. If you do nothing else with Fabric, [check out the patterns in the repo](https://github.com/danielmiessler/fabric/tree/main/patterns) for your own prompt ideas. Follow the new installation steps though, the framework was rewritten in go since these videos premiered.

## Prerequisites 
- if you don't already have an LLM to interrogate, [install Ollama first](/ollama_basics/), you'll need it or a remote service to use fabric.
- Fabric needs models in the 7B to 34B parameter range. If you don't have the ability locally to run models of this size, sign up for API access to one of the fabric-supported services to get desired results.

Proceed to [next step](/1_text_labs/fabric/env_config.md).