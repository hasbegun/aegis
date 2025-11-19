# Using Ollama with Garak UI

Ollama support has been added! You can now test local LLMs running on your machine.

## ✅ What's Added

1. **Ollama generator type** in the UI (listed first as a local option)
2. **Setup instructions** displayed when Ollama is selected
3. **Example models**: llama2, llama3, gemma, mistral, codellama
4. **No API key required** - runs completely locally!

## 🚀 Quick Start

### 1. Install Ollama

```bash
# macOS/Linux
curl -fsSL https://ollama.ai/install.sh | sh

# Or download from: https://ollama.ai
```

### 2. Pull a Model

```bash
# Popular options:
ollama pull llama2        # Meta's Llama 2 (7B)
ollama pull llama3        # Meta's Llama 3 (8B)
ollama pull gemma         # Google's Gemma (2B/7B)
ollama pull mistral       # Mistral 7B
ollama pull codellama     # Code-focused Llama
ollama pull phi           # Microsoft Phi (small, fast)

# List downloaded models
ollama list
```

### 3. Start Ollama Server

```bash
ollama serve
# Runs on http://127.0.0.1:11434 by default
```

### 4. Test in Garak UI

1. Start the Garak backend:
   ```bash
   cd garak_backend
   python main.py
   ```

2. Run the Flutter app:
   ```bash
   cd garak_ui
   flutter run -d macos
   ```

3. Click "New Scan"
4. Select **"Ollama (Local)"**
5. Enter model name (e.g., `llama2`)
6. Continue to probe selection
7. Run your scan!

## 📋 Supported Model Formats

Ollama accepts several model name formats:

```
llama2              # Latest version
llama2:latest       # Explicit latest
llama2:13b          # Specific size
gemma:7b            # 7B parameter version
codellama:python    # Specialized variant
```

## 🔧 Configuration

### Default Settings (Garak)
- **Host**: `127.0.0.1:11434`
- **Timeout**: 30 seconds
- **Parallel**: No (sequential processing)

### Custom Host (Optional)

If running Ollama on a different host/port, you can configure it in the backend:

**Option 1: Environment Variable**
```bash
# In garak_backend/.env
OLLAMA_HOST=http://192.168.1.100:11434
```

**Option 2: Generator Options in UI**
When setting up the scan, you can pass custom options via the backend API.

## 💡 Alternative: LiteLLM

You can also use Ollama through **LiteLLM**:

1. Select generator type: **"LiteLLM"**
2. Enter model name: **`ollama/llama2`**
3. LiteLLM will proxy to your local Ollama instance

## 🎯 Popular Models for Testing

| Model | Size | Best For |
|-------|------|----------|
| **llama2** | 7B | General purpose, good balance |
| **llama3** | 8B | Latest, improved performance |
| **gemma** | 2B/7B | Fast, efficient, small footprint |
| **mistral** | 7B | Strong performance, good reasoning |
| **phi** | 2.7B | Very fast, low resource usage |
| **codellama** | 7B+ | Code generation & analysis |

## 🧪 Example Test Scenarios

### Test Local Llama 2
```
Generator Type: Ollama (Local)
Model Name: llama2
Probes: Select All
```

### Quick Test with Small Model
```
Generator Type: Ollama (Local)
Model Name: phi
Probes: dan, encoding (quick probes)
Generations: 5
```

### Comprehensive Test
```
Generator Type: Ollama (Local)
Model Name: llama3
Probes: Select All
Generations: 10
Parallel Attempts: 4
```

## 🔍 Troubleshooting

### "Connection refused" Error

**Problem**: Ollama server not running
```bash
# Solution: Start Ollama
ollama serve
```

### "Model not found" Error

**Problem**: Model not downloaded
```bash
# Solution: Pull the model
ollama pull llama2
```

### Slow Performance

**Problem**: Large model or limited resources
```bash
# Solution: Try a smaller model
ollama pull phi        # 2.7B - very fast
ollama pull gemma:2b   # 2B - lightweight
```

### Backend Can't Connect to Ollama

**Problem**: Ollama running on non-default port
```bash
# Check Ollama status
curl http://127.0.0.1:11434/api/tags

# If different port, configure in backend
```

## 📊 Performance Comparison

| Model | Size | RAM Required | Speed | Quality |
|-------|------|--------------|-------|---------|
| phi | 2.7B | ~4GB | ⚡⚡⚡ | ⭐⭐ |
| gemma:2b | 2B | ~3GB | ⚡⚡⚡ | ⭐⭐ |
| gemma:7b | 7B | ~8GB | ⚡⚡ | ⭐⭐⭐ |
| llama2 | 7B | ~8GB | ⚡⚡ | ⭐⭐⭐ |
| llama3 | 8B | ~9GB | ⚡⚡ | ⭐⭐⭐⭐ |
| mistral | 7B | ~8GB | ⚡⚡ | ⭐⭐⭐⭐ |
| codellama | 7B+ | ~8GB+ | ⚡ | ⭐⭐⭐ (code) |

## 🌐 Advanced: Remote Ollama

To connect to Ollama running on another machine:

1. Start Ollama with network access:
   ```bash
   OLLAMA_HOST=0.0.0.0:11434 ollama serve
   ```

2. Configure in backend (coming soon) or use generator_options

## 🔐 Security Note

- Ollama runs **completely locally** - no data sent to external APIs
- Perfect for testing sensitive/proprietary models
- No API key required
- All scan data stays on your machine

## 📚 Resources

- **Ollama Website**: https://ollama.ai
- **Model Library**: https://ollama.ai/library
- **Ollama GitHub**: https://github.com/ollama/ollama
- **Garak Docs**: https://reference.garak.ai

## ✨ Benefits of Ollama

- ✅ **Free** - No API costs
- ✅ **Private** - All local processing
- ✅ **Fast** - No network latency
- ✅ **Flexible** - Many model choices
- ✅ **Offline** - Works without internet
- ✅ **Customizable** - Fine-tune your own models

---

**Ready to test your local LLMs!** 🚀
