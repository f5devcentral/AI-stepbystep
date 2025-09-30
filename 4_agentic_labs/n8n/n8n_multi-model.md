
# Goals

By the end of this lab, you will have created a flow that can help organizations to save money on AI spend by selecting the most appropriate model for a given task. A smaller model will classify a user's prmopt and will proxy the prompt on to another model, based on whether or not the prompt was needing reasoning, coding or something else and select a model that is designed for the need, rather than relying on the user understanding which model they should use for which tasks.

This lab assumes that you will be installing your models on one server and your n8n instasllation on its own machine, so that n8n's performance is not impacted by model inference.

## Prerequisites

1. You must have completed our [Ollama Basics lab](ollama_basics) to have an understanding of the installation and use of Ollama.
2. You must have completed one of our [n8n Installation labs](n8n), as well. This will lay the groundwork for the basics.
3. You must have docker installed and running on the machine you're using for the lab. It must also be configured for host networking or you will not be able to access your n8n implementation.

### Steps

1. Set docker to use the NVIDIA runtime on the LLM Server and restart the docker daemon:
`nvidia-ctk runtime configure --runtime=docker; systemctl restart docker`
2. Create a docker volume for persistent functionalityon the LLM Server:
`docker volume create model_data`
3. Install Ollama on the LLM Server using docker:
`docker run -d -v model_data:/root/.ollama -p 11434:11434 --name ollama ollama/ollama`
4. Install the models on the LLM Server that we'll be working with in this lab:
`docker exec ollama ollama pull deepseek-r1:1.5b`
`docker exec ollama ollama pull llama3.2:3b`
`docker exec ollama ollama pull deepseek-r1:7b`
`docker exec ollama ollama pull codellama`
5. Install n8n on the App Server:
`docker volume create n8n_data; docker run -it --rm --name n8n -p 5678:5678 -v n8n_data:/home/node/.n8n docker.n8n.io/n8nio/n8n`
6. Now, it's time to open your browser to <http://192.168.1.233:5678> (but use your host machine's IP address instead of that one) and create an owner account for the instance:
   ![img1](images/1_owner_account.png)
7. Click past the customization screen:
   ![img2](images/2_customize_screen.png)
8. Request your free community license activation key:
   ![img3](images/3_send_license.png)
9. Click usage and plan to enter your license key that should be in your email:
   ![img4](images/4_usage_plan.png)
10. Click the Enter activation key button and paste your key in from your email:
   ![img5](images/5_plan_screen.png)

   ![img6](images/6_key_pasted.png)
11. Create a new workflow by clicking the + button in the top left of the screen and select Workflow from the drop-down:
   ![img7](images/7_new_workflow.png)
12. Trigger your flow with a chat message. Click the big + in the center of the canvas and select On chat message.
   ![img20](images/20-chat-start.png)
13. Add a text classifier node
   ![img21](images/21-add-class.png)

   ![img22](images/22-add-class.png)
14. Classifier Parameters: Click and hold the 'chatInput' object in the JSON input view, then drag it into the 'Text to Classify' box.
   ![img23](images/23-drag-input.png)
15. Classifier Parameters: Click the 'Add Category' button. For the Category, enter 'Resoning' and for a description, enter 'If reasoning need is indicated by the chat message, this is the category to assign.'
   ![img24](images/24-cat-reas.png)
16. Classifier Parameters: Click the 'Add Category' button again. For the Category, enter 'Coding' and for the decription, enter 'If the chat message indicates a need to code or asks for help with computer languages and scripting languages like iRules, JSON or node.js, assign this category.'
   ![img25](images/25-cat-code.png)
17. Classifier Parameters: Click the 'Add Option' drop-down, select 'Allow Multiple Cases To Be True' and enable the feature.
   ![img26](images/26-opt-mult.png)
18. Add Option' drop-down, select 'When No Clear Match' and select the 'Output on Extra, Other Branch' option.
   ![img27](images/27-opt-other.png)
19. Classifier Parameters: Click the 'Add Option' drop-down, select 'System Prompt Template' and enter the following text or similar: 'Please classify the text provided by the user into one of the following categories: {categories}, and use the provided formatting instructions below: If they explicitly ask for coding help, do not fail and classify the message as 'Coding'. If they explicitly ask for reasoning help, do not fail and classify the message as 'Reasoning'. Otherwise, Send the  {{ $json.chatInput }} on to the next agent.'
   ![img28](images/28-opt-sys.png)
20. Classifier Settings: Select 'Retry On Fail', leave the default settings.
   ![img47](images/47-class-retry.png)
21. Click the Model '+' at the bootom of your Text Classifier object and add an Ollama model using your Ollama credentials. In the model drop-down, select the model deepseek-r1:1.5b, name it 'deepseek-r1:1.5b' and return to the canvas.
   ![img29](images/29-text-mod.png)
   ![img30](images/30-new-creds.png)
   ![img31](images/30-ip-creds.png)
   ![img32](images/32-deep1.5.png)
22. Click the Reasoning '+' at the right edge of your Text Classifier object and add an AI Agent object. This will immediately open the agent's configuration screen.
   ![img33](images/33-agent-add.png)
23. Click the Settings tab, select 'Retry On Fail' and leave the default settings. Rename the node 'Reasoning Agent' and return to canvas.
   ![img34](images/34-retry-fail.png)
24. Click the Chat Model '+' at the bottom of your Reasoning Agent object and add an Ollama model using your Ollama credentials. In the model drop-down, select the model deepseek-r1:7b, name it 'deepseek-r1:7b' and return to the canvas.
   ![img35](images/35-mod-deep-7b.png)
25. Click the Coding '+' at the right edge of your Text Classifier object and add an AI Agent object. This will immediately open the agent's configuration screen.
   ![img36](images/36-add-code.png)
26. Click the Settings tab, select 'Retry On Fail' and leave the default settings. Rename the node 'Coding Agent' and return to canvas.
   ![img37](images/37-retry-fail.png)
27. Click the Chat Model '+' at the bottom of your Coding Agent object and add an Ollama model using your Ollama credentials. In the model drop-down, select the model codellama:latest, name it 'codellama' and return to the canvas.
   ![img38](images/38-mod-codellama.png)
   ![img39](images/39-mod-codellama.png)
28. Click the Other '+' at the right edge of your Text Classifier object and add an AI Agent object. This will immediately open the agent's configuration screen.
   ![img40](images/40-add-gen.png)
29. Click the Settings tab, select 'Retry On Fail' and leave the default settings. Rename the node 'Generalist Agent' and return to canvas.
   ![img41](images/41-retry-fail.png)
30. Click the Chat Model '+' at the bottom of your Other Agent object and add an Ollama model using your Ollama credentials. In the model drop-down, select the model deepseek-r1:1.5b, name it 'deepseek-r1:1.5b' and return to the canvas.
   ![img42](images/42-mod-deep.png)
   ![img43](images/43-mod-deep.png)
31. Now, it's time to play. Open your n8n chat interface, if you haven't already and enter some prompts. These will take a bit. Watch how the objects in your flow pass data to one another by clicking on the object and observing the data that is input and output through each step in the flow. Observe how poor prompt engineering yields lessser results. What else do you see happening? Perhaps adjust your system prompt to the Text Classifier's attached model. What happens to your results if you change models on your agents?
   ![img44](images/44-finished.png)
   ![img45](images/45-test1.png)
   ![img45](images/45-test2.png)
   ![img46](images/46-test3.png)
