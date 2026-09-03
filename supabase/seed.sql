-- Local development seed. Applied by `supabase db reset`, NOT by `db push`.
-- Reference data (platforms, skills) lives in migrations instead, because
-- production needs it too.

insert into public.organizations
  (name, slug, organization_type, description, contact_email, city, verification_status)
values
  ('Sahaj Finance', 'sahaj-finance', 'nbfc',
   'Micro-lending NBFC underwriting gig workers on verified income history.',
   'credit@sahajfinance.example', 'Mumbai', 'verified'),
  ('Metro Logistics', 'metro-logistics', 'employer',
   'Fleet operator hiring verified delivery partners.',
   'hiring@metrologistics.example', 'Pune', 'verified'),
  ('SuRaksha Insurance', 'suraksha-insurance', 'insurer',
   'Accident and income-protection cover priced on work history.',
   'underwriting@suraksha.example', 'Bengaluru', 'verified')
on conflict (slug) do nothing;
