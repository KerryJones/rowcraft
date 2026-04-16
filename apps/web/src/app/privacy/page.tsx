import type { Metadata } from 'next';
import Link from 'next/link';

export const metadata: Metadata = {
  title: 'Privacy Policy — RowCraft',
};

export default function PrivacyPage() {
  return (
    <div className="mx-auto max-w-3xl px-4 py-12 sm:px-6">
      <h1 className="mb-2 text-3xl font-bold text-white">Privacy Policy</h1>
      <p className="mb-8 text-sm text-gray-500">Last updated: April 14, 2026</p>

      <div className="prose prose-invert prose-gray max-w-none space-y-6 text-sm leading-relaxed text-gray-300">
        <section>
          <h2 className="text-lg font-semibold text-white">1. Introduction</h2>
          <p>
            RowCraft (&quot;the Service&quot;) is operated by Kerry Jones. This Privacy Policy explains what data we
            collect, how we use it, and your rights regarding your personal information. We are committed to protecting
            your privacy and handling your data transparently.
          </p>
        </section>

        <section>
          <h2 className="text-lg font-semibold text-white">2. Data We Collect</h2>
          <p>We collect only the data necessary to provide the Service:</p>
          <ul className="list-disc space-y-1 pl-5">
            <li>
              <strong>Account information:</strong> Email address and password (password is hashed and stored securely
              by our authentication provider; we never see or store your plain-text password).
            </li>
            <li>
              <strong>Profile information:</strong> Display name (optional) and fitness settings such as your
              Functional Threshold Power (FTP) in watts and maximum heart rate.
            </li>
            <li>
              <strong>Workout data:</strong> Workouts you create, training plans, and workout results including
              distance, time, split times, stroke rate, heart rate, and watts.
            </li>
            <li>
              <strong>Device data:</strong> When you connect a Concept2 PM5 via Bluetooth Low Energy (BLE), we receive
              real-time performance data during your session. This data is processed to display live metrics and is
              stored as part of your workout results.
            </li>
          </ul>
          <p>
            We do <strong>not</strong> collect location data, device identifiers, browsing history, or any data beyond
            what is listed above.
          </p>
        </section>

        <section>
          <h2 className="text-lg font-semibold text-white">3. How We Use Your Data</h2>
          <p>Your data is used solely to provide and improve the Service:</p>
          <ul className="list-disc space-y-1 pl-5">
            <li>Authenticating your account and maintaining your session</li>
            <li>Displaying your workout history and progress</li>
            <li>Personalizing workout targets based on your FTP and heart rate settings</li>
            <li>Enabling you to share public workouts with other users</li>
          </ul>
          <p>
            We do <strong>not</strong> sell, rent, or share your personal data with third parties for marketing or
            advertising purposes. We do not use your data for profiling or automated decision-making.
          </p>
        </section>

        <section>
          <h2 className="text-lg font-semibold text-white">4. Cookies and Tracking</h2>
          <p>
            The Service uses only essential cookies required for authentication and session management. We do not use
            analytics cookies, advertising trackers, or any third-party tracking services.
          </p>
        </section>

        <section>
          <h2 className="text-lg font-semibold text-white">5. Data Storage and Security</h2>
          <p>
            Your data is stored on cloud infrastructure provided by Supabase. Data is encrypted in transit (TLS) and
            at rest. We implement reasonable security measures to protect your data, but no method of transmission or
            storage is 100% secure.
          </p>
        </section>

        <section>
          <h2 className="text-lg font-semibold text-white">6. Data Retention</h2>
          <p>
            We retain your data for as long as your account is active. If you{' '}
            <Link href="/delete-account" className="text-blue-400 hover:text-blue-300">delete your account</Link>,
            all associated personal data and workout history will be permanently deleted. Public workouts you created
            may be retained in anonymized form.
          </p>
        </section>

        <section>
          <h2 className="text-lg font-semibold text-white">7. Your Rights</h2>
          <p>You have the right to:</p>
          <ul className="list-disc space-y-1 pl-5">
            <li>
              <strong>Access your data:</strong> Request a summary of the personal data we hold about you by
              contacting us.
            </li>
            <li>
              <strong>Correct your data:</strong> Update your profile information at any time through the Service.
            </li>
            <li>
              <strong>Delete your data:</strong>{' '}
              <Link href="/delete-account" className="text-blue-400 hover:text-blue-300">Delete your account</Link>{' '}
              and all associated data at any time, or contact us at{' '}
              <a href="mailto:support@rowcraft.app" className="text-blue-400 hover:text-blue-300">
                support@rowcraft.app
              </a>.
            </li>
            <li>
              <strong>Export your data:</strong> Request a copy of your workout data by contacting us.
            </li>
          </ul>
        </section>

        <section>
          <h2 className="text-lg font-semibold text-white">8. Children&apos;s Privacy</h2>
          <p>
            The Service is not intended for children under the age of 13. We do not knowingly collect personal
            information from children under 13. If we learn that we have collected data from a child under 13, we will
            delete that data promptly. If you believe a child under 13 has provided us with personal information,
            please contact us.
          </p>
        </section>

        <section>
          <h2 className="text-lg font-semibold text-white">9. Third-Party Services</h2>
          <p>
            The Service offers optional integration with the Concept2 Logbook for syncing workout results. When you
            link your Concept2 account and sync a workout, your workout data (distance, time, split times, stroke
            rate) is transmitted to Concept2 and is subject to their privacy policy. You can disconnect your Concept2
            account at any time from your profile settings.
          </p>
          <p>
            We use Sentry for crash and error reporting. When the app encounters an error, Sentry may receive
            diagnostic data such as the error message, stack trace, and device type. This data is used solely to
            identify and fix bugs. Sentry does not receive your workout data, email address, or any personally
            identifiable information.
          </p>
        </section>

        <section>
          <h2 className="text-lg font-semibold text-white">10. Changes to This Policy</h2>
          <p>
            We may update this Privacy Policy from time to time. Changes will be posted on this page with an updated
            date. Your continued use of the Service after changes are posted constitutes acceptance of the revised
            policy.
          </p>
        </section>

        <section>
          <h2 className="text-lg font-semibold text-white">11. Contact</h2>
          <p>
            If you have any questions about this Privacy Policy or your data, please contact us at{' '}
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
