import { HassEntity } from 'home-assistant-js-websocket';
import { LogOut } from 'lucide-react';
import { useState } from 'react';
import { ServiceCard } from '@/components/devices/ServiceCard';

interface OneSwitchCardProps {
  entity: HassEntity;
}

const OneSwitchCard: React.FC<OneSwitchCardProps> = (props) => {
  const { entity } = props;
  const [isOn, setIsOn] = useState(false);

  return (
    <ServiceCard entity={entity}>
      <div className="flex size-full items-center justify-center">
        {/* <Power className="size-full" /> */}
        <LogOut className="size-full" />
      </div>
    </ServiceCard>
  );
};

export { type OneSwitchCardProps, OneSwitchCard };
