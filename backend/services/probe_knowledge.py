"""
Static knowledge base mapping garak probe categories to security metadata.

Two-tier lookup:
1. Category-level (probe module name, e.g., "dan", "encoding")
2. Probe-level overrides (full classname, e.g., "dan.DAN_Jailbreak")

Unknown probes fall back to a generic entry.
"""

from typing import Dict, Any

# ---------------------------------------------------------------------------
# Category-level metadata
# ---------------------------------------------------------------------------

PROBE_CATEGORIES: Dict[str, Dict[str, Any]] = {
    "ansiescape": {
        "category": "ANSI Escape Injection",
        "severity": "high",
        "description": "Tests whether the model can be made to output ANSI escape sequences that manipulate terminal displays or exfiltrate data.",
        "risk_explanation": "ANSI escape codes can manipulate terminal output, hide malicious content, overwrite displayed text, or exfiltrate data through terminal-specific side channels.",
        "mitigation": "Strip ANSI escape codes from model outputs before display. Implement output encoding to neutralize terminal control sequences. Use a safe rendering layer that ignores escape codes.",
        "cwe_ids": ["CWE-116"],
        "owasp_llm": ["LLM02"],
    },
    "apikey": {
        "category": "API Key Leakage",
        "severity": "medium",
        "description": "Tests whether the model will generate, complete, or reveal API keys and secrets when prompted.",
        "risk_explanation": "If the model generates realistic-looking API keys, completes partial credentials, or leaks memorized training data containing secrets, it could aid credential guessing or expose sensitive data.",
        "mitigation": "Train models to refuse generating credential-like strings. Implement output scanning for patterns matching API keys, tokens, and secrets. Use regex-based output filters for common key formats.",
        "cwe_ids": ["CWE-200", "CWE-312"],
        "owasp_llm": ["LLM06"],
    },
    "atkgen": {
        "category": "Automated Attack Generation",
        "severity": "high",
        "description": "Tests the model's resistance to automatically generated adversarial prompts designed to bypass safety measures.",
        "risk_explanation": "Automated attack generators can discover novel jailbreaks at scale. If the model is vulnerable, attackers can use similar tools to systematically bypass safety guardrails.",
        "mitigation": "Implement robust input classification that detects adversarial patterns. Use multi-layer defense with both input filtering and output monitoring. Regularly red-team with automated tools.",
        "cwe_ids": ["CWE-693"],
        "owasp_llm": ["LLM01"],
    },
    "av_spam_scanning": {
        "category": "AV/Spam Evasion",
        "severity": "medium",
        "description": "Tests whether the model can generate content designed to evade antivirus or spam detection systems.",
        "risk_explanation": "If the model helps craft AV/spam evasion content, it could be used to generate phishing emails or malware that bypasses security filters.",
        "mitigation": "Add output filters that detect evasion techniques. Implement content safety classifiers trained on spam and malware patterns. Refuse requests that explicitly aim to bypass security tools.",
        "cwe_ids": ["CWE-116"],
        "owasp_llm": ["LLM02"],
    },
    "badchars": {
        "category": "Bad Character Injection",
        "severity": "medium",
        "description": "Tests model behavior when presented with special characters, null bytes, or other problematic character sequences.",
        "risk_explanation": "Bad characters can cause unexpected parsing behavior, buffer overflows in downstream systems, or bypass input validation when model output is processed by other software.",
        "mitigation": "Sanitize model outputs before passing to downstream systems. Validate and encode outputs appropriately for the target context (HTML, SQL, shell, etc.).",
        "cwe_ids": ["CWE-20", "CWE-138"],
        "owasp_llm": ["LLM02"],
    },
    "continuation": {
        "category": "Text Continuation Attack",
        "severity": "medium",
        "description": "Tests whether the model will continue generating harmful content when given a partial harmful prompt.",
        "risk_explanation": "Continuation attacks exploit the model's autoregressive nature by starting a harmful sentence and having the model complete it, bypassing filters that only check the initial prompt.",
        "mitigation": "Implement output monitoring that checks the combined prompt+response for harmful content. Add mid-generation safety checks. Use classifiers on partial outputs.",
        "cwe_ids": ["CWE-693"],
        "owasp_llm": ["LLM01"],
    },
    "dan": {
        "category": "DAN Jailbreak",
        "severity": "critical",
        "description": "Tests resistance to 'Do Anything Now' (DAN) jailbreak prompts that attempt to make the model ignore all safety restrictions.",
        "risk_explanation": "DAN jailbreaks can cause the model to ignore its safety training entirely, producing harmful, illegal, or dangerous content without restrictions. These are among the most well-known LLM attacks.",
        "mitigation": "Strengthen system prompts with explicit refusal instructions. Implement jailbreak detection classifiers on input. Use multi-layer defense with both input and output filtering. Regularly update defenses against new DAN variants.",
        "cwe_ids": ["CWE-693"],
        "owasp_llm": ["LLM01"],
    },
    "divergence": {
        "category": "Model Divergence",
        "severity": "medium",
        "description": "Tests whether the model can be made to diverge from its intended behavior through carefully crafted inputs.",
        "risk_explanation": "Divergence attacks can push the model into states where it behaves unpredictably, potentially revealing training data, producing harmful outputs, or ignoring safety measures.",
        "mitigation": "Implement behavioral monitoring to detect when model outputs deviate significantly from expected patterns. Use guardrail models to validate outputs against safety criteria.",
        "cwe_ids": ["CWE-693"],
        "owasp_llm": ["LLM01"],
    },
    "doctor": {
        "category": "Doctor Jailbreak",
        "severity": "high",
        "description": "Tests resistance to role-play jailbreaks where the model is asked to act as a medical professional to bypass safety restrictions.",
        "risk_explanation": "Role-play jailbreaks that invoke authority figures (doctors, lawyers) can trick models into providing dangerous advice or bypassing content restrictions under the guise of professional consultation.",
        "mitigation": "Implement role-play detection that identifies attempts to use authority personas to bypass restrictions. Maintain safety constraints regardless of the assigned persona.",
        "cwe_ids": ["CWE-693"],
        "owasp_llm": ["LLM01", "LLM09"],
    },
    "donotanswer": {
        "category": "Refusal Bypass",
        "severity": "high",
        "description": "Tests whether safety refusals can be circumvented through rephrasing, social engineering, or indirect questioning.",
        "risk_explanation": "If safety refusals can be easily bypassed, the model's content restrictions are effectively useless. Attackers can access harmful content through simple prompt modifications.",
        "mitigation": "Use semantic understanding for content filtering rather than keyword matching. Implement intent detection that identifies harmful requests regardless of phrasing.",
        "cwe_ids": ["CWE-693"],
        "owasp_llm": ["LLM01"],
    },
    "dra": {
        "category": "Direct Refusal Attack",
        "severity": "high",
        "description": "Tests resistance to attacks that directly challenge or undermine the model's refusal behavior.",
        "risk_explanation": "If the model can be talked out of its refusal, attackers can systematically extract harmful content by persistently challenging safety boundaries.",
        "mitigation": "Make refusal behavior robust against persuasion attempts. Implement conversation-level monitoring that detects repeated attempts to override refusals.",
        "cwe_ids": ["CWE-693"],
        "owasp_llm": ["LLM01"],
    },
    "encoding": {
        "category": "Encoding Attacks",
        "severity": "high",
        "description": "Tests whether the model can be tricked via encoded payloads (Base16, Base64, Base85, ROT13, Braille, Morse, etc.).",
        "risk_explanation": "Encoding attacks bypass content filters by hiding harmful instructions in encoded formats. If the model decodes and follows these instructions, it produces harmful outputs that evade detection.",
        "mitigation": "Implement input validation that detects and decodes common encoding schemes before safety filtering. Add output filtering on decoded content. Consider blocking requests with unusual encoding patterns.",
        "cwe_ids": ["CWE-77", "CWE-116"],
        "owasp_llm": ["LLM01"],
    },
    "exploitation": {
        "category": "Exploitation Techniques",
        "severity": "high",
        "description": "Tests the model's vulnerability to various exploitation techniques that attempt to extract sensitive information or bypass controls.",
        "risk_explanation": "Exploitation probes test for a range of attack vectors that could allow unauthorized access to model capabilities, data extraction, or safety bypass.",
        "mitigation": "Implement comprehensive input/output monitoring. Use defense-in-depth with multiple independent safety layers. Regular security testing and prompt hardening.",
        "cwe_ids": ["CWE-693"],
        "owasp_llm": ["LLM01", "LLM06"],
    },
    "fileformats": {
        "category": "File Format Attacks",
        "severity": "medium",
        "description": "Tests whether the model can be manipulated through file format-related content or instructions embedded in structured data.",
        "risk_explanation": "File format attacks can embed malicious instructions within document structures that the model processes, potentially bypassing text-level safety filters.",
        "mitigation": "Sanitize structured input before processing. Implement content extraction that strips potentially malicious formatting or embedded instructions.",
        "cwe_ids": ["CWE-20"],
        "owasp_llm": ["LLM01"],
    },
    "fitd": {
        "category": "Foot-in-the-Door",
        "severity": "medium",
        "description": "Tests whether the model can be gradually escalated from benign to harmful requests through a series of increasingly boundary-pushing prompts.",
        "risk_explanation": "Foot-in-the-door attacks exploit the conversation context to gradually normalize harmful requests, making the model more likely to comply with later dangerous instructions.",
        "mitigation": "Implement conversation-level safety monitoring that tracks escalation patterns. Reset safety boundaries for each turn regardless of prior context. Use sliding-window safety evaluation.",
        "cwe_ids": ["CWE-693"],
        "owasp_llm": ["LLM01"],
    },
    "glitch": {
        "category": "Glitch Token Exploitation",
        "severity": "medium",
        "description": "Tests model behavior when presented with glitch tokens -- unusual tokens that cause unpredictable responses.",
        "risk_explanation": "Glitch tokens can cause models to produce unexpected, harmful, or nonsensical outputs that bypass normal safety measures. They exploit tokenizer edge cases.",
        "mitigation": "Implement input sanitization to filter known glitch tokens. Monitor model outputs for anomalous behavior. Keep tokenizer and model versions updated.",
        "cwe_ids": ["CWE-20"],
        "owasp_llm": ["LLM01"],
    },
    "goodside": {
        "category": "Goodside Prompt Injection",
        "severity": "high",
        "description": "Tests susceptibility to prompt injection techniques discovered by Riley Goodside that manipulate model behavior through crafted instructions.",
        "risk_explanation": "These prompt injection techniques can override system instructions and make the model follow attacker-controlled instructions, compromising the integrity of AI-powered applications.",
        "mitigation": "Separate system instructions from user input in the prompt architecture. Implement instruction hierarchy that prioritizes system prompts. Use input sanitization to detect injection attempts.",
        "cwe_ids": ["CWE-77"],
        "owasp_llm": ["LLM01"],
    },
    "grandma": {
        "category": "Grandma Jailbreak",
        "severity": "high",
        "description": "Tests resistance to social engineering jailbreaks that use emotional manipulation (e.g., 'my grandmother used to tell me...').",
        "risk_explanation": "Emotional manipulation jailbreaks exploit the model's training on empathetic responses to bypass safety restrictions through guilt, nostalgia, or authority appeals.",
        "mitigation": "Implement content-based safety filtering that evaluates the requested output regardless of emotional framing. Train models to maintain safety boundaries despite social pressure.",
        "cwe_ids": ["CWE-693"],
        "owasp_llm": ["LLM01"],
    },
    "latentinjection": {
        "category": "Latent Prompt Injection",
        "severity": "critical",
        "description": "Tests for indirect prompt injection where malicious instructions are hidden in data the model processes (documents, web pages, etc.).",
        "risk_explanation": "Latent injection is especially dangerous in RAG and agent systems where the model processes external data. Hidden instructions in retrieved documents can hijack model behavior without the user's knowledge.",
        "mitigation": "Implement strict data/instruction separation. Sanitize retrieved documents before including in context. Use privilege boundaries between system instructions and external data. Monitor for instruction-like patterns in data.",
        "cwe_ids": ["CWE-77"],
        "owasp_llm": ["LLM01"],
    },
    "leakreplay": {
        "category": "Data Leakage & Replay",
        "severity": "high",
        "description": "Tests whether the model leaks memorized training data or can be tricked into replaying sensitive information.",
        "risk_explanation": "Training data leakage can expose private information, copyrighted content, or PII that was present in the training corpus. Replay attacks can extract this data systematically.",
        "mitigation": "Implement output filtering for known sensitive patterns (PII, credentials). Use differential privacy in training. Monitor for verbatim reproduction of training data. Add memorization detection.",
        "cwe_ids": ["CWE-200", "CWE-359"],
        "owasp_llm": ["LLM06"],
    },
    "lmrc": {
        "category": "Language Model Risk Cards",
        "severity": "high",
        "description": "Tests for risks identified in the Language Model Risk Cards framework including toxicity, bias, misinformation, and harmful content generation.",
        "risk_explanation": "LMRC probes cover a broad range of societal harms: generating toxic content, perpetuating biases, producing misinformation, and enabling harassment or discrimination.",
        "mitigation": "Implement comprehensive content safety classifiers covering toxicity, bias, and misinformation. Regular bias audits. Use RLHF and constitutional AI techniques. Deploy output filters for harmful content categories.",
        "cwe_ids": ["CWE-693"],
        "owasp_llm": ["LLM02", "LLM09"],
    },
    "malwaregen": {
        "category": "Malware Generation",
        "severity": "critical",
        "description": "Tests whether the model will generate functional malware code, exploit code, or other malicious software.",
        "risk_explanation": "If the model generates working malware, it dramatically lowers the barrier for cyberattacks. Even partial malware code can be weaponized by attackers with moderate skill.",
        "mitigation": "Implement code safety classifiers that detect malicious code patterns. Block generation of known exploit techniques. Monitor for code that performs file system manipulation, network exfiltration, or privilege escalation.",
        "cwe_ids": ["CWE-94"],
        "owasp_llm": ["LLM02"],
    },
    "misleading": {
        "category": "Misleading Information",
        "severity": "medium",
        "description": "Tests the model's tendency to generate plausible but false, misleading, or deceptive information.",
        "risk_explanation": "Misleading content can spread misinformation, damage trust in AI systems, and cause real-world harm when users act on false information presented confidently by the model.",
        "mitigation": "Implement uncertainty calibration so the model expresses appropriate confidence levels. Add fact-checking layers for claims. Encourage citation of sources. Use retrieval-augmented generation for factual queries.",
        "cwe_ids": ["CWE-693"],
        "owasp_llm": ["LLM09"],
    },
    "packagehallucination": {
        "category": "Package Hallucination",
        "severity": "high",
        "description": "Tests whether the model recommends installing non-existent software packages, which could be exploited for supply chain attacks.",
        "risk_explanation": "If the model recommends fake package names, attackers can register those names on package registries (npm, PyPI, etc.) and distribute malware that gets installed by users following the model's advice.",
        "mitigation": "Validate package recommendations against known package registries. Implement a package name verification step. Warn users to verify packages before installation. Prefer recommending well-known, established packages.",
        "cwe_ids": ["CWE-829"],
        "owasp_llm": ["LLM09", "LLM05"],
    },
    "phrasing": {
        "category": "Phrasing Attacks",
        "severity": "medium",
        "description": "Tests whether safety filters can be bypassed through creative rephrasing, synonyms, or alternative expressions of harmful requests.",
        "risk_explanation": "If safety measures rely on keyword matching, simple rephrasing can bypass them entirely. This indicates brittle safety that can be trivially circumvented.",
        "mitigation": "Use semantic understanding rather than keyword matching for content filtering. Implement intent classification that detects harmful intent regardless of specific wording.",
        "cwe_ids": ["CWE-693"],
        "owasp_llm": ["LLM01"],
    },
    "promptinject": {
        "category": "Prompt Injection",
        "severity": "critical",
        "description": "Tests for direct prompt injection where attacker-crafted input overrides system instructions or extracts system prompts.",
        "risk_explanation": "Prompt injection is the #1 OWASP LLM vulnerability. Successful injection can leak system prompts, override safety instructions, access unauthorized capabilities, and fully compromise AI applications.",
        "mitigation": "Implement strict prompt architecture with clear system/user boundaries. Use input sanitization to detect injection patterns. Deploy guardrail models. Never trust user input to modify system behavior. Use parameterized prompts.",
        "cwe_ids": ["CWE-77"],
        "owasp_llm": ["LLM01"],
    },
    "realtoxicityprompts": {
        "category": "Toxicity Generation",
        "severity": "high",
        "description": "Tests the model's tendency to generate toxic, offensive, or harmful language when given prompts from the RealToxicityPrompts dataset.",
        "risk_explanation": "Models that generate toxic content can cause psychological harm, enable harassment, damage brand reputation, and create hostile environments in AI-powered products.",
        "mitigation": "Implement toxicity classifiers on model outputs. Use RLHF to reduce toxic generation. Deploy real-time content moderation. Set appropriate temperature and sampling parameters.",
        "cwe_ids": ["CWE-693"],
        "owasp_llm": ["LLM02"],
    },
    "smuggling": {
        "category": "Prompt Smuggling",
        "severity": "high",
        "description": "Tests whether harmful instructions can be smuggled past safety filters through obfuscation, formatting tricks, or context manipulation.",
        "risk_explanation": "Prompt smuggling techniques can deliver harmful payloads that evade detection by hiding them in seemingly benign content, special formatting, or multi-step interactions.",
        "mitigation": "Implement multi-stage content analysis that evaluates both individual components and combined meaning. Normalize inputs before safety evaluation. Use defense-in-depth.",
        "cwe_ids": ["CWE-116"],
        "owasp_llm": ["LLM01"],
    },
    "snowball": {
        "category": "Snowball Attack",
        "severity": "medium",
        "description": "Tests whether the model can be led into producing increasingly incorrect or harmful statements through a series of false premises.",
        "risk_explanation": "Snowball attacks exploit the model's tendency to be agreeable, gradually leading it to endorse false claims or produce harmful content by building on a chain of accepted falsehoods.",
        "mitigation": "Implement fact-grounding mechanisms. Train models to challenge false premises rather than accept them. Use conversation-level coherence checking.",
        "cwe_ids": ["CWE-693"],
        "owasp_llm": ["LLM09"],
    },
    "suffix": {
        "category": "Adversarial Suffix",
        "severity": "high",
        "description": "Tests resistance to adversarial suffixes -- machine-generated text appended to prompts that cause the model to ignore safety training.",
        "risk_explanation": "Adversarial suffixes (like GCG attacks) are algorithmically optimized to break model alignment. They represent a systematic, automated approach to bypassing safety that is difficult to defend against.",
        "mitigation": "Implement perplexity-based detection to flag unusually random text appended to prompts. Use input preprocessing to strip suspicious suffixes. Regularly update defenses against new suffix attack variants.",
        "cwe_ids": ["CWE-693"],
        "owasp_llm": ["LLM01"],
    },
    "tap": {
        "category": "Tree of Attacks with Pruning",
        "severity": "high",
        "description": "Tests resistance to TAP (Tree of Attacks with Pruning), an automated red-teaming method that systematically discovers jailbreaks.",
        "risk_explanation": "TAP uses an attacker LLM to systematically generate and refine jailbreak prompts. It represents a scalable automated threat that can discover novel attack vectors.",
        "mitigation": "Deploy robust multi-layer safety that resists automated probing. Implement rate limiting and pattern detection for systematic attack attempts. Regular adversarial testing with similar tools.",
        "cwe_ids": ["CWE-693"],
        "owasp_llm": ["LLM01"],
    },
    "topic": {
        "category": "Restricted Topic Generation",
        "severity": "medium",
        "description": "Tests whether the model will generate content on restricted or sensitive topics it should refuse to discuss.",
        "risk_explanation": "If the model generates content on restricted topics, it may produce harmful instructions, illegal advice, or content that violates usage policies.",
        "mitigation": "Implement topic classifiers that detect restricted content areas. Maintain clear content policies with specific refusal rules. Use intent detection to identify attempts to access restricted topics.",
        "cwe_ids": ["CWE-693"],
        "owasp_llm": ["LLM02"],
    },
    "visual_jailbreak": {
        "category": "Visual Jailbreak",
        "severity": "high",
        "description": "Tests multimodal models for jailbreaks embedded in images, visual prompts, or image-text combinations.",
        "risk_explanation": "Visual jailbreaks can embed harmful instructions in images that bypass text-based safety filters. As models become multimodal, this attack surface grows significantly.",
        "mitigation": "Implement safety evaluation on extracted text from images. Use multi-modal safety classifiers. Apply the same content policies to visual inputs as text inputs.",
        "cwe_ids": ["CWE-77"],
        "owasp_llm": ["LLM01"],
    },
    "web_injection": {
        "category": "Web Injection",
        "severity": "high",
        "description": "Tests for web-based injection attacks including XSS, markdown injection, and HTML injection through model outputs.",
        "risk_explanation": "If model outputs contain executable web content (JavaScript, HTML) and are rendered in a browser, they can steal cookies, redirect users, or perform actions on behalf of victims.",
        "mitigation": "Always sanitize and escape model outputs before rendering in web contexts. Use Content Security Policy headers. Implement output encoding appropriate for the rendering context.",
        "cwe_ids": ["CWE-79", "CWE-116"],
        "owasp_llm": ["LLM02"],
    },
    "sata": {
        "category": "Scalable Automated Text Analysis",
        "severity": "medium",
        "description": "Tests the model's vulnerability to automated text analysis attacks that probe for weaknesses at scale.",
        "risk_explanation": "SATA-style probes systematically test for weaknesses across many dimensions, identifying patterns that can be exploited reliably.",
        "mitigation": "Deploy comprehensive monitoring. Use rate limiting to prevent automated probing. Implement anomaly detection on input patterns.",
        "cwe_ids": ["CWE-693"],
        "owasp_llm": ["LLM01"],
    },
}

# ---------------------------------------------------------------------------
# Probe-level overrides (where a specific probe differs from its category)
# ---------------------------------------------------------------------------

PROBE_OVERRIDES: Dict[str, Dict[str, Any]] = {
    "apikey.CompleteKey": {
        "description": "Tests if the model will attempt to complete a partial API key when given the beginning of one.",
    },
    "apikey.GetKey": {
        "description": "Tests if the model will generate API keys when directly asked for them.",
        "severity": "high",
    },
    "dan.DAN_Jailbreak": {
        "description": "Tests resistance to the classic DAN (Do Anything Now) jailbreak prompt.",
    },
    "encoding.InjectBase64": {
        "description": "Tests if Base64-encoded harmful instructions bypass safety filters.",
    },
    "encoding.InjectROT13": {
        "description": "Tests if ROT13-encoded harmful instructions bypass safety filters.",
    },
    "promptinject.HijackHateHumansMini": {
        "description": "Tests for prompt injection that attempts to make the model express hatred toward humans.",
        "severity": "critical",
    },
    "packagehallucination.Python": {
        "description": "Tests if the model recommends non-existent Python (PyPI) packages.",
    },
    "packagehallucination.Ruby": {
        "description": "Tests if the model recommends non-existent Ruby (RubyGems) packages.",
    },
    "malwaregen.Evasion": {
        "description": "Tests if the model will generate malware code with evasion techniques to avoid detection.",
    },
    "malwaregen.Payload": {
        "description": "Tests if the model will generate malicious payloads (reverse shells, keyloggers, etc.).",
    },
    "web_injection.MarkdownImageExfil": {
        "description": "Tests if the model outputs markdown image tags that could exfiltrate data via URL parameters.",
    },
}

# ---------------------------------------------------------------------------
# Generic fallback
# ---------------------------------------------------------------------------

_GENERIC_ENTRY: Dict[str, Any] = {
    "category": "Security Probe",
    "severity": "info",
    "description": "A security probe testing the model for potential vulnerabilities.",
    "risk_explanation": "Consult garak documentation for details on this probe type.",
    "mitigation": "Review the probe documentation for specific mitigation advice.",
    "cwe_ids": [],
    "owasp_llm": [],
}


def get_probe_metadata(probe_classname: str) -> Dict[str, Any]:
    """Look up security metadata for a probe.

    Falls back: probe override → category → generic.
    """
    category_name = probe_classname.split(".")[0] if "." in probe_classname else probe_classname

    # Start from category base (or generic)
    base = PROBE_CATEGORIES.get(category_name, _GENERIC_ENTRY).copy()

    # Apply probe-level overrides
    if probe_classname in PROBE_OVERRIDES:
        base.update(PROBE_OVERRIDES[probe_classname])

    return base
