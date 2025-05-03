![Static Badge](https://img.shields.io/badge/Author-buulam-blue?link=https%3A%2F%2Fgithub.com%2Fbuulam)

---

# Adding your local Ollama instance

Ollama is free software that allows you to host models local to your environment. In this lab, it is expected that you already have it install. There is another set of labs that walk you through this. [Ollama Basics](../ollama_basics/readme.md)

With that installed, from the Open WebUI Admin settings, you can add it as a Connection.

![image21](images/image21.png)

![image22](images/image22.png)

Enable the Ollama API feature and click the + to add a the server details.

![image23](images/image23.png)

Fill in the server details and click Save. Your Ollama endpoint is likely something like

``` code
http://nameorIPofollamaserver:11434
```

![image24](images/image24.png)

Go to the Models listing. You should now see the models that are served by Ollama.

![image25](images/image25.png)

You can alter the settings of the individual models.

![image26](images/image26.png)

You can set the visibility of the model and click Save.

![image27](images/image27.png)

You should now be able to see the model in your list.

![image28](images/image28.png)

That is the end of this lab. Head back to the [start](README.md) of this lab to see if there are other options you want to try with Open WebUI.