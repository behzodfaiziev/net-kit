import type { Rule, RuleInfo } from '../types.js';
import { nk002, nk007, nk011, nk014, nk015, nk016 } from './auth.js';
import { nk005 } from './migration.js';
import { nk001, nk003, nk006, nk009 } from './transport.js';
import { nk004, nk008, nk010, nk012, nk013 } from './upload.js';

/** Every semantic rule, in id order. */
export const RULES: readonly Rule[] = [
  nk001,
  nk002,
  nk003,
  nk004,
  nk005,
  nk006,
  nk007,
  nk008,
  nk009,
  nk010,
  nk011,
  nk012,
  nk013,
  nk014,
  nk015,
  nk016,
];

export const RULE_CATALOG: readonly RuleInfo[] = RULES.map(
  ({ id, title, categories, description }) => ({
    id,
    title,
    categories,
    description,
  }),
);

/** Rule ids each focused review runs. */
export const REVIEW_RULES = {
  auth: ['NK001', 'NK002', 'NK003', 'NK005', 'NK007', 'NK009', 'NK011', 'NK015'],
  refresh: ['NK005', 'NK007', 'NK014'],
  upload: ['NK001', 'NK003', 'NK004', 'NK008', 'NK009', 'NK013'],
  streaming: ['NK004', 'NK010', 'NK013'],
  migration: ['NK005', 'NK006'],
  configuration: ['NK005', 'NK011', 'NK012', 'NK014', 'NK015', 'NK016'],
} as const;
