# How to run Custom LLM Models on OCP AI

Install hf cli  
Log into huggingface:  

```
hf auth login
```

Downloads the model to a local folder. Example:  
```
hf download Qwen/Qwen3-VL-8B-Thinking-FP8 --local-dir models/Qwen3-VL-8B-Thinking-FP8
```

Upload it to an S3 object storage.
Deploy it on OCP AI