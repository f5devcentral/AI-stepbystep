![Static Badge](https://img.shields.io/badge/Author-buulam-blue?link=https%3A%2F%2Fgithub.com%2Fbuulam)

---
# LLM server and Open WebUI

This lab will guide you through a basic scenario that provides you will a simple to use web front end to interact with AI models for both text and images.

The web front end is meant to be run from a "server" of your own. In this lab, the models can either be run locally using Ollama and/or from OpenAI through the use of their APIs.

## Practical usage

Aside from the learning aspect of this, you could look at using this as a method to make AI services available to your household. There are interesting benefits this way:

* Save money from subscribing to AI chat services by consolidating individual family members subscriptions. It is likely that using an AI service's API will be far cheaper than a single subscription, let alone if you have mutiple people in your household using services.
* Keep an eye on what your kids are doing with AI with the ability to monitor their chats.
* Experiment with the latest models quickly as you can switch models quickly. As well, services like OpenAI typically will have their latest models available via API before their general subscription service.

## Services in this lab

```mermaid
graph LR

A[Open WebUI] --> B[Ollama]
A --> C[OpenAI API]
B --> D[o1]
B --> E[gpt4.0]
B --> F[mistral]

```


| Service | Description | 
|---------|-------------|
| Open WebUI | Web front end and router of AI models |
| Ollama | Local LLM runtime |
| OpenAI API | LLM service |

## Lab environment

For this lab you will need:
* 1x Ubuntu linux server
  * If only installing Open WebUI, this could be as small as a Raspberry Pi
  * If running Ollama, a general purpose CPU is fine but a GPU is recommended if using regularly
* API key from OpenAI if you want to use those services
  * See this [https://platform.openai.com/docs/overview] link for details

Proceed to [next steps](01-prep.md)