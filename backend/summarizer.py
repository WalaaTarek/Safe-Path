from sumy.parsers.plaintext import PlaintextParser
from sumy.nlp.tokenizers import Tokenizer
from sumy.summarizers.text_rank import TextRankSummarizer
import re


def clean_for_summarizer(text):
    text = re.sub(r'\s+', ' ', text)
    return text.strip()


def local_summarize(text, sentences_count=5):
    text = clean_for_summarizer(text)

    parser = PlaintextParser.from_string(text, Tokenizer("english"))
    summarizer = TextRankSummarizer()

    summary = summarizer(parser.document, sentences_count)

    return "\n".join(str(sentence) for sentence in summary)


def summarize_if_large(text, pages_count):
    if pages_count > 5:
        return local_summarize(text)
    return text