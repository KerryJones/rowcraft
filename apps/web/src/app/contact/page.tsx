import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'Contact — RowCraft',
  description: 'Get in touch with the RowCraft team.',
};

export default function ContactPage() {
  return (
    <div className="mx-auto max-w-3xl px-4 py-12 sm:px-6">
      <h1 className="mb-8 text-3xl font-bold text-white">Contact</h1>

      <div className="prose prose-invert prose-gray max-w-none space-y-6 text-sm leading-relaxed text-gray-300">
        <section>
          <h2 className="text-lg font-semibold text-white">Get in Touch</h2>
          <p>
            RowCraft is built and maintained by Kerry Jones. Whether you have a question, found a bug, or
            just want to say hello, I&apos;d love to hear from you.
          </p>
        </section>

        <section>
          <h2 className="text-lg font-semibold text-white">Email</h2>
          <p>
            The best way to reach me is by email at{' '}
            <a href="mailto:support@rowcraft.app" className="text-blue-400 hover:text-blue-300">
              support@rowcraft.app
            </a>
            .
          </p>
        </section>

        <section>
          <h2 className="text-lg font-semibold text-white">Bug Reports &amp; Feature Requests</h2>
          <p>
            If you&apos;ve found a bug or have an idea for a feature, send an email
            to{' '}
            <a href="mailto:support@rowcraft.app" className="text-blue-400 hover:text-blue-300">
              support@rowcraft.app
            </a>{' '}
            with as much detail as possible. Screenshots and steps to reproduce are always helpful.
          </p>
        </section>

        <section>
          <h2 className="text-lg font-semibold text-white">Support RowCraft</h2>
          <p>
            RowCraft is a free, independently developed tool for the rowing community. If you find it
            useful and want to support its continued development, you can buy me a coffee.
          </p>
          <p>
            <a
              href="https://buymeacoffee.com/kerryjones"
              target="_blank"
              rel="noopener noreferrer"
              className="text-blue-400 hover:text-blue-300"
            >
              buymeacoffee.com/kerryjones
            </a>
          </p>
        </section>
      </div>
    </div>
  );
}
