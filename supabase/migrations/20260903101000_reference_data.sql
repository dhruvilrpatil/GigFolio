-- =====================================================================
-- 11. Reference data
--     Platforms and skills are shared vocabulary, not demo data, so they
--     ship as a migration and are idempotent on re-run.
-- =====================================================================

insert into public.platforms (slug, name, category, supports_api, supported_methods, website_url)
values
  ('uber',           'Uber',            'transportation', true,  '{oauth,document_upload}',      'https://uber.com'),
  ('ola',            'Ola',             'transportation', false, '{document_upload,manual_entry}', 'https://olacabs.com'),
  ('rapido',         'Rapido',          'transportation', false, '{document_upload,manual_entry}', 'https://rapido.bike'),
  ('namma-yatri',    'Namma Yatri',     'transportation', true,  '{oauth,manual_entry}',         'https://nammayatri.in'),
  ('swiggy',         'Swiggy',          'delivery',       false, '{document_upload,manual_entry}', 'https://swiggy.com'),
  ('zomato',         'Zomato',          'delivery',       false, '{document_upload,manual_entry}', 'https://zomato.com'),
  ('zepto',          'Zepto',           'delivery',       false, '{document_upload,manual_entry}', 'https://zeptonow.com'),
  ('blinkit',        'Blinkit',         'delivery',       false, '{document_upload,manual_entry}', 'https://blinkit.com'),
  ('amazon-flex',    'Amazon Flex',     'logistics',      false, '{document_upload,manual_entry}', 'https://flex.amazon.in'),
  ('porter',         'Porter',          'logistics',      false, '{document_upload,manual_entry}', 'https://porter.in'),
  ('urban-company',  'Urban Company',   'home_services',  false, '{document_upload,manual_entry}', 'https://urbancompany.com'),
  ('housejoy',       'Housejoy',        'home_services',  false, '{manual_entry}',               'https://housejoy.in'),
  ('upwork',         'Upwork',          'freelancing',    true,  '{oauth,api_key}',              'https://upwork.com'),
  ('fiverr',         'Fiverr',          'freelancing',    false, '{document_upload,manual_entry}', 'https://fiverr.com'),
  ('freelancer',     'Freelancer',      'freelancing',    true,  '{oauth,api_key}',              'https://freelancer.com'),
  ('toptal',         'Toptal',          'freelancing',    false, '{manual_entry}',               'https://toptal.com'),
  ('vedantu',        'Vedantu',         'education',      false, '{manual_entry}',               'https://vedantu.com'),
  ('other',          'Other / Offline', 'other',          false, '{manual_entry}',               null)
on conflict (slug) do nothing;

insert into public.skills (slug, name, category, description)
values
  ('two-wheeler-riding',   'Two-Wheeler Riding',      'transportation', 'Licensed two-wheeler operation for delivery or passenger transport'),
  ('four-wheeler-driving', 'Four-Wheeler Driving',    'transportation', 'Commercial car driving with a valid licence'),
  ('heavy-vehicle',        'Heavy Vehicle Operation', 'logistics',      'Trucks, tempos and commercial goods vehicles'),
  ('route-navigation',     'Route Navigation',        'delivery',       'Efficient routing in dense urban areas'),
  ('last-mile-delivery',   'Last-Mile Delivery',      'delivery',       'Doorstep delivery, handover and proof-of-delivery'),
  ('cold-chain-handling',  'Cold Chain Handling',     'delivery',       'Temperature-sensitive goods handling'),
  ('customer-service',     'Customer Service',        null,             'Courteous customer interaction and complaint handling'),
  ('electrical-repair',    'Electrical Repair',       'home_services',  'Household wiring, fixtures and appliance electrics'),
  ('plumbing',             'Plumbing',                'home_services',  'Fittings, leak repair and pipeline installation'),
  ('carpentry',            'Carpentry',               'home_services',  'Furniture assembly, repair and fitting'),
  ('appliance-repair',     'Appliance Repair',        'home_services',  'Refrigerator, washing machine and AC servicing'),
  ('deep-cleaning',        'Deep Cleaning',           'home_services',  'Professional home and office cleaning'),
  ('beauty-wellness',      'Beauty and Wellness',     'home_services',  'Salon and grooming services at home'),
  ('cooking',              'Cooking',                 'home_services',  'Meal preparation and kitchen management'),
  ('child-care',           'Child Care',              'care_giving',    'Supervision and care of children'),
  ('elder-care',           'Elder Care',              'care_giving',    'Assisted living support for senior citizens'),
  ('web-development',      'Web Development',         'freelancing',    'Front-end and back-end web application development'),
  ('mobile-development',   'Mobile Development',      'freelancing',    'Android and iOS application development'),
  ('graphic-design',       'Graphic Design',          'freelancing',    'Visual design, branding and layout'),
  ('video-editing',        'Video Editing',           'freelancing',    'Post-production and motion graphics'),
  ('content-writing',      'Content Writing',         'freelancing',    'Articles, copy and technical documentation'),
  ('data-entry',           'Data Entry',              'freelancing',    'Accurate high-volume data capture'),
  ('digital-marketing',    'Digital Marketing',       'freelancing',    'SEO, ads and social media campaigns'),
  ('tutoring',             'Tutoring',                'education',      'Academic instruction and exam preparation'),
  ('spoken-english',       'Spoken English',          'education',      'Conversational English instruction'),
  ('retail-sales',         'Retail Sales',            'retail',         'In-store selling and merchandising'),
  ('inventory-management', 'Inventory Management',    'logistics',      'Stock tracking, picking and packing')
on conflict (slug) do nothing;
