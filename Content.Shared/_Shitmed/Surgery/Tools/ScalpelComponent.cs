using Robust.Shared.GameStates;

namespace Content.Shared._Shitmed.Medical.Surgery.Tools;

[RegisterComponent, NetworkedComponent, AutoGenerateComponentState]
public sealed partial class ScalpelComponent : Component, ISurgeryToolComponent
{
    public string ToolName { get; set; } = "a scalpel";
    public bool? Used { get; set; } = null;
    [DataField, AutoNetworkedField]
    public float Speed { get; set; } = 1f;
}
