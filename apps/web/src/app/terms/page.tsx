import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'Terms of Service — RowCraft',
  description: 'Terms of service for using RowCraft.',
};

export default function TermsPage() {
  return (
    <div className="mx-auto max-w-3xl px-4 py-12 sm:px-6">
      <h1 className="mb-2 text-3xl font-bold text-white">Terms of Service</h1>
      <p className="mb-8 text-sm text-gray-500">Last updated: April 5, 2026</p>

      <div className="prose prose-invert prose-gray max-w-none space-y-6 text-sm leading-relaxed text-gray-300">
        <section>
          <h2 className="text-lg font-semibold text-white">1. Acceptance of Terms</h2>
          <p>
            By accessing or using RowCraft (&quot;the Service&quot;), operated by Kerry Jones, you agree to be bound by
            these Terms of Service. If you do not agree to these terms, do not use the Service.
          </p>
        </section>

        <section>
          <h2 className="text-lg font-semibold text-white">2. Description of Service</h2>
          <p>
            RowCraft is a workout tracking application designed for use with Concept2 rowing ergometers. The Service
            allows users to browse, create, and execute structured rowing workouts, track workout results, and connect
            to Concept2 PM5 performance monitors via Bluetooth Low Energy (BLE).
          </p>
        </section>

        <section>
          <h2 className="text-lg font-semibold text-white">3. Eligibility</h2>
          <p>
            You must be at least 13 years of age to use the Service. By using the Service, you represent and warrant
            that you are at least 13 years old. If you are under 18, you represent that you have your parent or
            guardian&apos;s permission to use the Service.
          </p>
        </section>

        <section>
          <h2 className="text-lg font-semibold text-white">4. User Accounts</h2>
          <p>
            To access certain features, you must create an account. You are responsible for maintaining the
            confidentiality of your account credentials and for all activity that occurs under your account. You agree
            to notify us immediately of any unauthorized use of your account.
          </p>
        </section>

        <section>
          <h2 className="text-lg font-semibold text-white">5. User-Generated Content</h2>
          <p>
            You may create workouts, training plans, and other content through the Service (&quot;User Content&quot;).
            You retain ownership of your User Content. By making User Content public on the Service, you grant RowCraft
            a non-exclusive, worldwide, royalty-free license to display, distribute, and make available your User
            Content to other users of the Service.
          </p>
          <p>
            You represent that you have the right to share any User Content you create and that it does not infringe
            on the rights of any third party.
          </p>
        </section>

        <section>
          <h2 className="text-lg font-semibold text-white">6. Intellectual Property</h2>
          <p>
            The Service, including its design, code, workout definitions, and documentation, is the property of Kerry
            Jones and is protected by applicable intellectual property laws. You may not copy, modify, distribute, or
            reverse-engineer any part of the Service except as expressly permitted.
          </p>
        </section>

        <section>
          <h2 className="text-lg font-semibold text-white">7. Health and Exercise Disclaimer</h2>
          <p>
            The Service is not a medical device and does not provide medical advice. Workouts provided through the
            Service are for informational and fitness purposes only. You should consult a physician before beginning
            any exercise program.
          </p>
          <p>
            You acknowledge that rowing and physical exercise carry inherent risks of injury. You use the Service and
            perform any workouts entirely at your own risk. RowCraft is not liable for any injury, illness, or health
            condition that may result from your use of the Service.
          </p>
        </section>

        <section>
          <h2 className="text-lg font-semibold text-white">8. Device Connectivity</h2>
          <p>
            The Service may connect to Concept2 PM5 performance monitors via Bluetooth Low Energy (BLE). RowCraft does
            not guarantee continuous, error-free connectivity with any device. BLE connections may be affected by
            environmental factors, device firmware, operating system compatibility, and other variables outside our
            control.
          </p>
        </section>

        <section>
          <h2 className="text-lg font-semibold text-white">9. Concept2 Trademark Notice</h2>
          <p>
            RowCraft is not affiliated with, endorsed by, or sponsored by Concept2, Inc. Concept2&reg; is a registered trademark of Concept2, Inc. PM5 is a product name of
            Concept2, Inc. All references to Concept2 products are for descriptive purposes
            only.
          </p>
        </section>

        <section>
          <h2 className="text-lg font-semibold text-white">10. Termination</h2>
          <p>
            We reserve the right to suspend or terminate your account at any time, with or without cause, and with or
            without notice. You may delete your account at any time through the Service. Upon termination, your right
            to use the Service ceases immediately.
          </p>
        </section>

        <section>
          <h2 className="text-lg font-semibold text-white">11. Limitation of Liability</h2>
          <p>
            To the maximum extent permitted by law, RowCraft and its operator shall not be liable for any indirect,
            incidental, special, consequential, or punitive damages, or any loss of profits, data, or goodwill,
            arising out of or in connection with your use of the Service.
          </p>
          <p>
            The Service is provided &quot;as is&quot; and &quot;as available&quot; without warranties of any kind,
            either express or implied, including but not limited to implied warranties of merchantability, fitness for
            a particular purpose, and non-infringement.
          </p>
        </section>

        <section>
          <h2 className="text-lg font-semibold text-white">12. Changes to Terms</h2>
          <p>
            We may update these Terms of Service from time to time. Changes will be posted on this page with an
            updated date. Your continued use of the Service after changes are posted constitutes acceptance of the
            revised terms.
          </p>
        </section>

        <section>
          <h2 className="text-lg font-semibold text-white">13. Governing Law</h2>
          <p>
            These Terms shall be governed by and construed in accordance with the laws of the State of California,
            United States, without regard to its conflict of law provisions.
          </p>
        </section>

        <section>
          <h2 className="text-lg font-semibold text-white">14. Contact</h2>
          <p>
            If you have any questions about these Terms of Service, please contact us at{' '}
            <a href="mailto:support@rowcraft.app" className="text-blue-400 hover:text-blue-300">
              support@rowcraft.app
            </a>
            .
          </p>
        </section>
      </div>
    </div>
  );
}
