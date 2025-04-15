# Using exiting fabric patterns

Now that you have fabric installed and configured, let's try it out with two patterns:

1. Reference an article using the gemma3:1b model and use the extract_article_wisdom pattern

`fabric -u https://github.blog/developer-skills/programming-languages-and-frameworks/why-python-keeps-growing-explained/ -m gemma3:1b extract_article_wisdom`

I won't paste the entire response, but here's the start of the detailed breakdown:
<pre>**1. Introduction (Paragraph 1)**

*   **Strengths:** Clearly states the document's purpose – to guide readers through learning Python.
*   **Improvement Suggestion:** Could briefly mention the growing demand for Python skills.

**2. Why Python? (Paragraph 2)**

*   **Strengths:**  Highlights Python's versatility across domains (data science, web development, automation, etc.).
*   **Improvement Suggestion:** Briefly mention its ease of use and large community support.</pre>

2. Reference a YouTube video using the gemma3:1b model and use the rate_value pattern (**Note**: you'll need to re-run fabric setup for this one and set your Youtube API key)

`fabric -y "https://www.youtube.com/watch?v=BV6-PsToR6w" -m gemma3:1b rate_value`

Here's the output (reduced for brevity):

<pre>Okay, here’s a breakdown of the text, categorized for clarity and with some observations:

**1. Overview & Introduction (First 2-3 Paragraphs)**

*   **Goal:** The video introduces the topic of potato growing and highlights the ease and fun of the method.
*   **Method Focus:** The video emphasizes the “Ruth Stout Method” – a simple, no-work approach for growing potatoes.
*   **Tone:** The voice-over is enthusiastic and slightly humorous, emphasizing the enjoyment of the process.

**2. The Ruth Stout Method – Core Explanation**

*   **Digging a Trench:** The core of the method is digging a shallow trench (about 18 inches deep) and dropping potatoes into it.
*   **Why it Works:** The voice-over explains that this method helps prevent the potatoes from being hit by the sun, resulting in a greener, more flavorful potato. It’s a bit of a quirky explanation.
*   **Yield:** It’s presented as a "lazy potato method" – a way to avoid hill-forming.

**Overall, the text is a concise and entertaining guide to growing potatoes using a simple and somewhat unconventional method.** It’s well-paced and uses humor to engage the listener/viewer.</pre>

I'm using a really small local Ollama model, so the quality of response is going to be reduced, but how cool is that to get a look at the intangibles around the content?

# Conclusion

In this lab, we used two existing patterns in the fabric framework to analyze content from an article and a video. Go check out the [patterns library](https://github.com/danielmiessler/fabric/tree/main/patterns), and when you're ready, [create your own](/fabric/custom_patterns.md)!
