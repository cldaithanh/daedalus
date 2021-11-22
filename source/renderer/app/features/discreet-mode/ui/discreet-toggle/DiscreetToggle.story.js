// @flow
import React from 'react';
import { storiesOf } from '@storybook/react';
import { withKnobs } from '@storybook/addon-knobs';
import { action } from '@storybook/addon-actions';
import { DiscreetToggleButton } from './DiscreetToggle';

storiesOf('Discreet Mode|Discreet Toggle', module)
  .addDecorator(withKnobs)
  .add('Main', () => (
    <div style={{ padding: 20 }}>
      <div style={{ marginBottom: 20 }}>
        <DiscreetToggleButton onToggle={action('onChange')} isDiscreetMode />
      </div>
      <div>
        <DiscreetToggleButton
          onToggle={action('onChange')}
          isDiscreetMode={false}
        />
      </div>
    </div>
  ));
