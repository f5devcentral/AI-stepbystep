# Using exiting fabric patterns

Now that you have Fabric installed and configured, let's try it out!

Prerequisite for the first example:
- A youtube account with a valid API key

1. Rate the content of a youtube video using the OpenAI gtp-4o-mini model.

`fabric -y "https://www.youtube.com/watch?v=BV6-PsToR6w" -m gpt-4o-mini -sp rate_content`

I won't paste the entire response, but here's the meat that matters:
<pre>LABELS:

Potatoes, Gardening, Agriculture, Horticulture, Botany, Sustainability, Food, Cultivation, Techniques, Harvesting, Soil, Organic, Methods, Education, Homegrown, Tips, DIY, Nature, Environment

RATING:

B Tier: (Consume Original When Time Allows)

Explanation:
- The content contains a substantial amount of practical gardening information, particularly about potato cultivation.
- It discusses various types of potatoes and their characteristics, which is valuable for gardeners.
- The focus on different planting methods and tips caters to a wide audience, including beginners and experienced gardeners.
- While it does not strongly engage with deeper themes like AI or abstract thinking, it does touch upon continuous improvement in gardening practices.
- Overall, the content is informative but lacks broader thematic connections to human meaning or the future of AI.

CONTENT SCORE:

75</pre>

How cool is that?

2.  Extract the wisdom from an article on LaGrange points with the OpenAI gpt-4o-mini model

`fabric -u "https://www.sciencefocus.com/space/lagrange-points" -m gpt-4o-mini -sp extract_article_wisdom`

Here's part of the output (reduced to two bullets per section for brevity):

<pre>### SUMMARY
The article by Science Focus discusses Lagrange points, five gravitational balance points between massive bodies where smaller objects can maintain equilibrium.

### IDEAS:
- Lagrange points are locations where gravitational forces balance between two massive bodies.
- There are five Lagrange points (L1 to L5) in each body orbiting system.

### QUOTES:
- "When two massive bodies orbit each other, there are five locations around these bodies where the gravitational forces balance."
- "A spacecraft or natural object can orbit the Sun, while keeping a position relative to the Sun and the Earth."


### FACTS:
- Lagrange points exist in all major bodies in the Solar System.
- There are five Lagrange points in each orbiting system.


### REFERENCES:
- James Webb Space Telescope
- NASA’s Wilkinson Microwave Anisotropy Probe (WMAP)


### RECOMMENDATIONS:
- Explore the concept of Lagrange points further for space mission planning.
- Consider L2 for future deep space observatories due to its advantages.</pre>

Sometimes I want to read for the experience, but for research, the efficiency of concept building with a tool like this is awesome.

# Conclusion

In this lab, we used two existing patterns in the fabric framework to analyze content from a video and article. Make sure you check out the [patterns library](https://github.com/danielmiessler/fabric/tree/main/patterns), and when you're ready, [create your own](/fabric/custom_patterns.md)!
