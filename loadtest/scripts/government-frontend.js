import { check } from 'k6';
import http from 'k6/http';
import { Counter } from 'k6/metrics';

export const requests = new Counter('http_reqs');

const targetRPS = 20;
export const options = {
  maxRedirects: 0,
  // Model a constant arrival rate (λ); see
  // https://k6.io/docs/using-k6/scenarios/arrival-rate/
  // https://en.wikipedia.org/wiki/Queueing_theory
  scenarios: {
    open_model: {
      executor: 'ramping-arrival-rate',
      startRate: 1,
      timeUnit: '1s',
      preAllocatedVUs: targetRPS,
      maxVUs: targetRPS + 10,
      stages: [
        { duration: '10s', target: targetRPS },
        { duration: '900s', target: targetRPS },
      ],
    },
  },
  thresholds: {
    http_req_failed: ['rate<0.01'],
    http_req_duration: ['p(95)<400', 'p(99)<1000', 'avg<400'],
  },
};

export default function () {
  // https://github.com/alphagov/government-frontend/#schemas
  const paths = [
    '/national-minimum-wage-rates',
    '/government/case-studies/2013-elections-in-swaziland',
    '/government/consultations/soft-drinks-industry-levy',
    '/government/organisations/hm-revenue-customs/contact/excise-enquiries',
    '/government/organisations/government-digital-service/about',
    '/guidance/waste-exemption-nwfd-2-temporary-storage-at-the-place-of-production--2',
    '/government/collections/statutory-guidance-schools',
    '/government/fatalities/corporal-lee-churcher-dies-in-iraq',
    '/help/about-govuk',
    '/government/publications/budget-2016-documents/budget-2016',
    '/log-in-register-hmrc-online-services',
    '/government/news/the-personal-independence-payment-amendment-regulations-2017-statement-by-paul-gray',
    '/government/publications/budget-2016-documents',
    '/business-finance-support/access-to-finance-advice-north-west-england',
    '/government/statistics/announcements/diagnostic-imaging-dataset-for-september-2015',
    '/government/statistical-data-sets/unclaimed-estates-list',
    '/government/speeches/government-at-your-service-ben-gummer-speech',
    '/government/get-involved/take-part/become-a-councillor',
    '/government/topical-events/2014-overseas-territories-joint-ministerial-council/about',
    '/foreign-travel-advice/nepal',
    '/government/groups/abstraction-reform',
  ];
  let path = paths[Math.floor(Math.random() * paths.length)];
  const res = http.get('http://chris-government-frontend' + path, options);
  const checkRes = check(res, {
    'status 200': (r) => r.status == 200,
    'contains self-link': (r) => r.body.indexOf(path) !== -1,
    'not a GOV.UK error page': (r) => r.body.indexOf('tatus code') === -1,
  });
}
