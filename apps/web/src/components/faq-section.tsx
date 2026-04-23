'use client';

import { Accordion, AccordionItem, AccordionTrigger, AccordionContent } from '@/components/ui/accordion';

export interface FaqItem {
  question: string;
  answer: string;
}

export function FaqSection({ items, heading = 'Frequently Asked Questions' }: { items: FaqItem[]; heading?: string }) {
  return (
    <section className="mx-auto max-w-3xl">
      <h2 className="mb-4 text-xl font-semibold text-white">{heading}</h2>
      <Accordion className="rounded-xl border border-gray-800 bg-gray-900 px-4">
        {items.map((item) => (
          <AccordionItem key={item.question} className="border-gray-800">
            <AccordionTrigger className="text-gray-200">{item.question}</AccordionTrigger>
            <AccordionContent className="text-gray-400">{item.answer}</AccordionContent>
          </AccordionItem>
        ))}
      </Accordion>
    </section>
  );
}
