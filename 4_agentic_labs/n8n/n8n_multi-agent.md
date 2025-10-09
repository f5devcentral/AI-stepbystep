# n8n Multi-Agent Workflow Lab

## Goals

By the end of this lab, you will have created a flow that can help organizations to save money on AI spend by selecting the most appropriate model for a given task. A smaller model will classify a user's prompt and will proxy the prompt on to another model, based on whether or not the prompt was needing reasoning, coding or something else and select a model that is designed for the need, rather than relying on the user understanding which model they should use for which tasks.

**Architecture Note:** This lab uses a two-server setup where models run on a dedicated LLM Server and n8n runs on a separate App Server to ensure n8n's performance isn't impacted by model inference.

## Prerequisites:

1. **[Ollama Basics lab](ollama_basics)** to have an understanding of the installation and use of Ollama.
2. **[n8n Installation labs](n8n)**, as well. This will lay the groundwork for the basics.
3. **Docker Requirements**
   - Docker installed and running on both machines
   - Docker configured for host networking (required for n8n access)

## Installation Steps

### LLM Server Setup

**Step 1:** Configure Docker to use NVIDIA runtime and restart the daemon:
```bash
nvidia-ctk runtime configure --runtime=docker
systemctl restart docker
```

**Step 2:** Create a Docker volume for persistent data:
```bash
docker volume create model_data
```

**Step 3:** Install Ollama using Docker:
```bash
docker run -d -v model_data:/root/.ollama -p 11434:11434 --name ollama ollama/ollama
```

**Step 4:** Pull the required models:
```bash
docker exec ollama ollama pull deepseek-r1:1.5b
docker exec ollama ollama pull llama3.2:3b
docker exec ollama ollama pull deepseek-r1:7b
docker exec ollama ollama pull codellama
```

### N8N Server Setup

**Step 5:** Install n8n on the App Server:
```bash
docker volume create n8n_data
docker run -it --rm --name n8n -p 5678:5678 -v n8n_data:/home/node/.n8n docker.n8n.io/n8nio/n8n
```

### N8N Initial Configuration

**Step 6:** Open your browser to `http://192.168.1.233:5678` (replace with your App Server's IP address) and create an owner account:

![Owner Account Setup](images/1_owner_account.png)

**Step 7:** Click past the customization screen:

![Customization Screen](images/2_customize_screen.png)

**Step 8:** Request your free community license activation key:

![License Request](images/3_send_license.png)

**Step 9:** Navigate to Usage and Plan to enter your license key:

![Usage and Plan](images/4_usage_plan.png)

**Step 10:** Click "Enter activation key" and paste your key from email:

![Plan Screen](images/5_plan_screen.png)
![Key Pasted](images/6_key_pasted.png)

---

## Workflow Creation

### Create New Workflow

**Step 11:** Create a new workflow by clicking the **+** button in the top left and select **Workflow** from the dropdown:

![New Workflow](images/7_new_workflow.png)

### Add Chat Trigger

**Step 12:** Trigger your flow with a chat message. Click the large **+** in the center of the canvas and select **On chat message**:

![Chat Start](images/20-chat-start.png)

---

## Configure Text Classifier

### Add Classifier Node

**Step 13:** Add a Text Classifier node:

![Add Classifier](images/21-add-class.png)
![Add Classifier Confirmation](images/22-add-class.png)

### Classifier Input Configuration

**Step 14:** Configure the input parameter:
- Select the **JSON view** in the left input panel
- Click and hold the `chatInput` object in the JSON input view
- Drag it into the **Text to Classify** box

![Drag Input](images/23-drag-input.png)

### Define Categories

**Step 15:** Add the Reasoning category:
- Click the **Add Category** button
- **Category:** `Reasoning`
- **Description:** `If reasoning need is indicated by the chat message, this is the category to assign.`

![Reasoning Category](images/24-cat-reas.png)

**Step 16:** Add the Coding category:
- Click the **Add Category** button again
- **Category:** `Coding`
- **Description:** `If the chat message indicates a need to code or asks for help with computer languages and scripting languages like iRules, JSON or node.js, assign this category.`

![Coding Category](images/25-cat-code.png)

### Configure Classifier Options

**Step 17:** Enable multiple category matching:
- Click the **Add Option** dropdown
- Select **Allow Multiple Cases To Be True**
- Enable the feature

![Multiple Cases](images/26-opt-mult.png)

**Step 18:** Configure fallback behavior:
- Click the **Add Option** dropdown
- Select **When No Clear Match**
- Choose **Output on Extra, Other Branch**

![Other Branch](images/27-opt-other.png)

**Step 19:** Set the system prompt:
- Click the **Add Option** dropdown
- Select **System Prompt Template**
- Enter the following:

```
Please classify the text provided by the user into one of the following categories: {categories}, and use the provided formatting instructions below: If they explicitly ask for coding help, do not fail and classify the message as 'Coding'. If they explicitly ask for reasoning help, do not fail and classify the message as 'Reasoning'. Otherwise, send the {{ $json.chatInput }} on to the next agent.
```

![System Prompt](images/28-opt-sys.png)

**Step 20:** Enable retry on failure:
- Open **Settings** tab
- Select **Retry On Fail**
- Leave default settings
- Return to canvas

![Classifier Retry](images/47-class-retry.png)

### Attach Classifier Model

**Step 21:** Add the classification model:
- Click the **Model +** button at the bottom of the Text Classifier
- Add an **Ollama model**
- Use existing Ollama credentials or create new ones (replace 'localhost' with your LLM Server IP)
- Select model: `deepseek-r1:1.5b`
- Name it: `deepseek-r1:1.5b`
- Return to canvas

![Text Model](images/29-text-mod.png)

![New Credentials](images/30-new-creds.png)

![IP Credentials](images/31-ip-creds.png)

![DeepSeek 1.5B](images/32-deep1.5.png)

---

## Configure AI Agents

### Reasoning Agent

**Step 22:** Add the Reasoning Agent:
- Click the **Reasoning +** at the right edge of the Text Classifier
- Add an **AI Agent** object

![Agent Add](images/33-agent-add.png)

**Step 23:** Configure Reasoning Agent settings:
- Click the **Settings** tab
- Select **Retry On Fail** (leave default settings)
- Rename the node to: `Reasoning Agent`
- Return to canvas

![Retry Fail](images/34-retry-fail.png)

**Step 24:** Attach the reasoning model:
- Click the **Chat Model +** at the bottom of the Reasoning Agent
- Add an **Ollama model** using your credentials
- Select model: `deepseek-r1:7b`
- Name it: `deepseek-r1:7b`
- Return to canvas

![DeepSeek 7B Model](images/35-mod-deep7b.png)

### Coding Agent

**Step 25:** Add the Coding Agent:
- Click the **Coding +** at the right edge of the Text Classifier
- Add an **AI Agent** object

![Add Code Agent](images/36-add-code.png)

**Step 26:** Configure Coding Agent settings:
- Click the **Settings** tab
- Select **Retry On Fail** (leave default settings)
- Rename the node to: `Coding Agent`
- Return to canvas

![Retry Fail](images/37-retry-fail.png)

**Step 27:** Attach the coding model:
- Click the **Chat Model +** at the bottom of the Coding Agent
- Add an **Ollama model** using your credentials
- Select model: `codellama:latest`
- Name it: `codellama`
- Return to canvas

![CodeLlama Model](images/38-mod-codellama.png)

![CodeLlama Confirmation](images/39-mod-codellama.png)

### Generalist Agent

**Step 28:** Add the Generalist Agent:
- Click the **Other +** at the right edge of the Text Classifier
- Add an **AI Agent** object

![Add General Agent](images/40-add-gen.png)

**Step 29:** Configure Generalist Agent settings:
- Click the **Settings** tab
- Select **Retry On Fail** (leave default settings)
- Rename the node to: `Generalist Agent`
- Return to canvas

![Retry Fail](images/41-retry-fail.png)

**Step 30:** Attach the generalist model:
- Click the **Chat Model +** at the bottom of the Generalist Agent
- Add an **Ollama model** using your credentials
- Select model: `deepseek-r1:1.5b`
- Name it: `deepseek-r1:1.5b`
- Return to canvas

![DeepSeek Model](images/42-mod-deep.png)

![DeepSeek Confirmation](images/43-mod-deep.png)

---

## Testing and Experimentation

**Step 31:** Test your workflow:
- Open your n8n chat interface
- Enter various prompts (note: responses may take some time)
- Click on workflow objects to observe data flow between steps
- Monitor how data passes through each step

![Finished Workflow](images/44-finished.png)

![Test Example 1](images/45-test1.png)

![Test Example 2](images/45-test2.png)

![Test Example 3](images/46-test3.png)

### Experimentation Ideas

- **Observe prompt engineering impact:** Notice how poorly engineered prompts yield lesser results
- **Modify the system prompt:** Adjust the Text Classifier's system prompt and observe changes
- **Swap models:** Try different models on your agents and compare results
- **Analyze data flow:** Watch how different prompt types trigger different agent paths

---

## Summary

You now have a functional multi-model workflow that:
- Automatically classifies user prompts
- Routes requests to specialized models
- Optimizes AI spend by using appropriately-sized models
- Demonstrates intelligent prompt routing architecture