import { Card } from '@/components/ui/card';
import { HassEntity } from 'home-assistant-js-websocket';

interface DefaultCardProps {
  entity: HassEntity;
}
const DefaultCard: React.FC<DefaultCardProps> = (props) => {
  const { entity } = props;

  return (
    <Card className={`h-full w-full p-4`}>
      <div className="h-full">
        <p className="line-clamp-2">{entity.entity_id}</p>
        <p className="line-clamp-2">{entity.attributes.friendly_name}</p>
      </div>
    </Card>
  );
};

export { type DefaultCardProps, DefaultCard };
