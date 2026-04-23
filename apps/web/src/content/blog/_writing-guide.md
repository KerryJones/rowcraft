# Clear Writing Style Guide

## Inspiration Sources

This writing style is based on these masters of clear communication:

**Primary Influences**

- **Randall Munroe** - Author of "Thing Explainer" (book using only 1,000 most common words)
- **Scott Adams** - The Day You Became A Better Writer
- **Paul Graham** - Writing, Briefly
- **Ben Thompson** - Stratechery blog (known for clear tech/business analysis)
- **Mark Twain** - "I didn't have time to write a short letter, so I wrote a long one instead"

Study these writers. Read their work. Notice how they make complex ideas simple.

## Core Philosophy

Write like you're explaining something important to a smart friend who's new to the topic. Every sentence should earn its place.

## Writing Principles

### 1. Use Simple Words

Choose the common word over the fancy one.

- "Use" not "utilize"
- "Help" not "facilitate"
- "Start" not "commence"

If you must use a technical term, explain it immediately in plain language.

### 2. Write Short Sentences

- Aim for 15-20 words per sentence
- One idea per sentence
- Break complex thoughts into multiple sentences
- Use periods more than commas

### 3. Structure for Scanning

- **Bold the key concept** in each paragraph
- Use bullet points for lists
- Keep paragraphs to 3-4 sentences
- Add white space between sections
- Use headers to break up content

### 4. Be Concrete

- Use specific examples over abstract concepts
- Show with numbers when possible
- Replace vague words with precise ones
- "Tomorrow at 3pm" not "soon"

### 5. Cut Ruthlessly

- Remove words that don't add meaning
- Delete entire sentences if they repeat ideas
- Avoid throat-clearing phrases like "It's important to note that..."
- Start with your point, don't build up to it

### 6. Test Your Writing

Ask yourself:

- Could a high school student understand this?
- Does each sentence move the idea forward?
- Am I saying this the shortest way possible?
- Would I say this out loud to a friend?

## Formatting Rules

### Headers

- **H1**: The big promise (what they'll learn)
- **H2**: Major sections (4-6 per article)
- **H3**: Specific points within sections
- Make headers complete thoughts, not just labels

### Visual Hierarchy

- **Bold**: Key concepts and important warnings
- *Italics*: Sparingly, only for emphasis
- Highlight boxes: Critical warnings or key takeaways
- Checklists: For action items readers should complete

### Lists

- Use bullets for unordered items
- Use numbers only when order matters
- Keep list items parallel in structure
- No periods unless it's a complete sentence

## What to Avoid

- Jargon without explanation
- Passive voice ("The loan was approved" -> "We approved the loan")
- Filler phrases ("basically," "essentially," "in order to")
- Long introductions - get to the point
- Apologizing for your content
- Marketing fluff or corporate speak

## The Final Test

Read your work out loud. If you stumble or run out of breath, rewrite that sentence. If you wouldn't say it in conversation, don't write it.

## Examples of the Style

**Too Complex:**
"The utilization of comprehensive due diligence procedures is essential for minimizing potential financial exposure in private lending transactions."

**Clear Version:**
"Check everything before you lend. It keeps your money safe."

**Too Complex:**
"Borrowers should endeavor to maintain consistent communication with their lending partners throughout the duration of the loan term."

**Clear Version:**
"Stay in touch with your lender. A quick monthly text works."

## Remember

You're not dumbing down the content. You're making complex ideas accessible. There's genius in simplicity. The goal is to help readers understand and act, not to impress them with vocabulary.

As Scott Adams says: "Simple means getting rid of extra words. Don't write, 'He was very happy' when you can write 'He was happy.'"

## Blog Post Conventions

### Frontmatter Format

Every `.mdx` file needs this frontmatter:

```yaml
---
title: "Post Title Here"
description: "One sentence. Used in meta tags and post cards."
date: "2026-04-23"
author: "Kerry Jones"
tags: ["rowing", "training"]
published: true
---
```

### File Naming

- Use kebab-case: `heart-rate-zones-rowing.mdx`
- Keep names short but descriptive
- Slug = filename without `.mdx`

### Adding a New Post

1. Create a `.mdx` file in `apps/web/src/content/blog/`
2. Add frontmatter (see above)
3. Write content using standard Markdown
4. Deploy. That's it.

Files prefixed with `_` (like this guide) are excluded from the blog listing.
