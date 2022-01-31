import React, { Component } from 'react';
import { inject, observer } from 'mobx-react';
import TopBar from '../../components/layout/TopBar';
import TopBarLayout from '../../components/layout/TopBarLayout';
import AnalyticsDialog from '../../components/profile/analytics/AnalyticsDialog';
import type { InjectedProps } from '../../types/injectedPropsType';

@inject('stores', 'actions')
@observer
class AnalyticsPage extends Component<InjectedProps> {
  static defaultProps = {
    actions: null,
    stores: null,
  };
  onSubmit = () => {
    this.props.actions.profile.acceptAnalytics.trigger();
  };

  render() {
    const { app, networkStatus, profile } = this.props.stores;
    const { setAnalyticsAcceptanceRequest } = profile;
    const { currentRoute } = app;
    const { isShelleyActivated } = networkStatus;
    const topbar = (
      <TopBar
        currentRoute={currentRoute}
        showSubMenuToggle={false}
        isShelleyActivated={isShelleyActivated}
      />
    );
    return (
      <TopBarLayout topbar={topbar}>
        {/* todo discuss error handling */}
        <AnalyticsDialog
          loading={setAnalyticsAcceptanceRequest.isExecuting}
          onConfirm={this.onSubmit}
        />
      </TopBarLayout>
    );
  }
}

export default AnalyticsPage;