import { SunDim, Sun as SunIcon } from 'lucide-react';
import { Card } from '@/components/ui/card';
import { Slider } from '@/components/ui/slider-ios';
import { Badge } from '@/components/ui/badge';
import { HassEntity } from 'home-assistant-js-websocket';
import { useHomeAssistant } from '@/use-home-assistant';
import { useEffect, useState, useCallback, useMemo } from 'react';
import { twMerge } from 'tailwind-merge';
import clsx from 'clsx';

const useColorTemp = (entity: HassEntity) => {
  const [minColorTempKelvin, maxColorTempKelvin] = [
    entity.attributes.min_color_temp_kelvin,
    entity.attributes.max_color_temp_kelvin,
  ];
  const [colorTempKelvin, setColorTempKelvin] = useState(minColorTempKelvin);

  useEffect(() => {
    setColorTempKelvin(entity.attributes.color_temp_kelvin);
  }, [entity]);

  const isSupported = entity.attributes.supported_color_modes.includes('color_temp');

  if (!isSupported) {
    return { isSupported };
  }

  return { isSupported, minColorTempKelvin, maxColorTempKelvin, colorTempKelvin };
};

interface LightCardProps {
  entity: HassEntity;
}

const LightCard = (props: Readonly<LightCardProps>) => {
  const { entity } = props;
  const { toggleLight: _toggleLight, changeLightAttributes: _changeLightAttributes } =
    useHomeAssistant();
  const { isSupported: isColorTempSupported } = useColorTemp(entity);
  const brightnessPercent = useMemo(() => {
    return Math.round((entity.attributes.brightness / 255) * 100) || 0;
  }, [entity.attributes.brightness]);
  const colorTempKelvin = useMemo(() => {
    return entity.attributes.color_temp_kelvin || 0;
  }, [entity.attributes.color_temp_kelvin]);

  const toggleLight = useCallback(() => {
    _toggleLight(entity.entity_id);
  }, [_toggleLight, entity.entity_id]);

  const handleBrightnessChange = useCallback(
    (value: number[]) => {
      _changeLightAttributes(entity.entity_id, { brightness: value[0] });
    },
    [_changeLightAttributes, entity.entity_id]
  );

  const handleColorTempChange = useCallback(
    (value: number[]) => {
      _changeLightAttributes(entity.entity_id, { color_temp_kelvin: value[0] });
    },
    [_changeLightAttributes, entity.entity_id]
  );

  return (
    <Card
      className={twMerge(
        clsx('group relative h-full w-full max-w-sm p-4', {
          'bg-amber-50': entity.state === 'on',
          'cursor-not-allowed opacity-50': entity.state === 'unavailable',
        })
      )}
    >
      <div className="h-full overflow-hidden">
        <div className="mb-4 flex items-start justify-between">
          <div>
            <Badge variant="secondary" className="mb-2">
              主卧室
            </Badge>
            <h3 className="text-lg font-semibold">{entity.attributes.friendly_name}</h3>
          </div>
          <div className="flex items-center space-x-2">
            <button
              className={`flex size-10 items-center justify-center rounded-full ${
                entity.state === 'on' ? 'bg-amber-500 text-white' : 'bg-gray-200 text-gray-500'
              }`}
              onClick={toggleLight}
            >
              <SunIcon />
            </button>
          </div>
        </div>

        {isColorTempSupported && (
          <>
            <div className="mb-4">
              <div className="mb-2 flex items-center justify-between">
                <span className="text-sm text-gray-600">亮度</span>
                <span className="text-sm font-medium">{brightnessPercent}%</span>
              </div>
              <Slider
                defaultValue={[entity.attributes.brightness]}
                max={255}
                min={1}
                step={1}
                className={twMerge(
                  clsx('w-full', {
                    'cursor-pointer': entity.state === 'on',
                    'cursor-not-allowed': entity.state === 'unavailable',
                  })
                )}
                onValueChange={handleBrightnessChange}
              />
            </div>
            <div>
              <div className="mb-2 flex items-center justify-between">
                <span className="text-sm text-gray-600">色温</span>
                <span className="text-sm font-medium">{colorTempKelvin}K</span>
              </div>
              <div className="relative">
                <Slider
                  defaultValue={[colorTempKelvin]}
                  max={entity.attributes.max_color_temp_kelvin}
                  min={entity.attributes.min_color_temp_kelvin}
                  step={1}
                  onValueChange={handleColorTempChange}
                  className={twMerge(
                    clsx('w-full', {
                      'cursor-pointer': entity.state === 'on',
                      'cursor-not-allowed': entity.state === 'unavailable',
                    })
                  )}
                />
                <div className="mt-1 flex justify-between">
                  <SunDim className="h-4 w-4 text-amber-400" />
                  <SunDim className="h-4 w-4 text-blue-400" />
                </div>
              </div>
            </div>
          </>
        )}
      </div>
      {entity.state === 'unavailable' && (
        <div className="invisible absolute -top-10 left-1/2 -translate-x-1/2 whitespace-nowrap rounded bg-gray-800 px-3 py-1 text-sm text-white transition-all duration-200 group-hover:visible">
          此设备当前不可用
        </div>
      )}
    </Card>
  );
};

export default LightCard;
