# AI PowerPoint Generator

An application that uses AI to automatically generate professional PowerPoint presentations from user prompts.

## Features

- Generate complete presentations with just a title and description
- Multiple design themes to choose from
- AI-generated content with bullet points
- Download as PowerPoint (.pptx) files

## Installation

### Requirements

- Ruby 3.x
- Rails 8.x
- Python 3.x with python-pptx
- PostgreSQL

### Setup

1. Clone this repository

# Design Guidelines

## Styling Framework

This application uses **Tailwind CSS** for styling. When making changes, please adhere to Tailwind's utility-first approach.

## Design Philosophy

Keep designs clean and intuitive. Avoid overly complex layouts or designs that deviate significantly from standard web practices. Focus on:

- Consistent spacing
- Clear visual hierarchy
- Responsive layouts
- Accessible contrast ratios

## Color Palette

The application uses the following color palette:

| Color  | Hex Code  | Description             |
| ------ | --------- | ----------------------- |
| Yellow | `#FFBE0B` | Primary accent color    |
| Orange | `#FB5607` | Secondary accent color  |
| Pink   | `#FF006E` | Highlight color         |
| Purple | `#8338EC` | Background accent color |
| Blue   | `#3A86FF` | Primary brand color     |

### Implementation with Tailwind

When implementing these colors, use Tailwind's custom color configuration or the closest built-in alternatives:

```html
<!-- Examples of using colors with Tailwind classes -->
<div class="bg-[#FFBE0B] text-[#3A86FF]">Yellow background with blue text</div>
<button class="bg-[#FF006E] hover:bg-[#FB5607] text-white">
  Pink button with orange hover
</button>
<div class="border-[#8338EC] border-2">Purple border</div>
```

For gradient combinations, consider:

```html
<div class="bg-gradient-to-r from-[#FFBE0B] to-[#FB5607]">
  Yellow to orange gradient
</div>
<div class="bg-gradient-to-r from-[#FF006E] to-[#8338EC]">
  Pink to purple gradient
</div>
```

Ensure sufficient contrast between text and background colors to maintain accessibility standards.
