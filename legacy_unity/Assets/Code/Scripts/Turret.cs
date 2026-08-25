using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;
using UnityEditor;

public class Turret : MonoBehaviour {

    // References to various objects and components in the Unity Editor
    [Header("References")]
    [SerializeField] private Transform turretRotationPoint;
    [SerializeField] private LayerMask enemyMask;
    [SerializeField] private GameObject bulletPrefab;
    [SerializeField] private Transform firingPoint;
    [SerializeField] private GameObject upgradeUI;
    [SerializeField] private Button upgradeButton;

    // Turret attributes that can be adjusted in the Unity Editor
    [Header("Attribute")]
    [SerializeField] private float targetingRange = 5f;
    [SerializeField] private float rotationSpeed = 5f;
    [SerializeField] private float bps = 1f;  // Bullets per second
    [SerializeField] private int baseUpgradeCost = 100;

    // Base values for attributes, to be used for upgrades
    private float bpsBase;
    private float targetingRangeBase;

    // Current target and time until the turret can fire again
    private Transform target;
    private float timeUntilFire;

    // Turret level and its initial values
    private int level = 1;

    // Initialize base values and set up the upgrade button listener
    private void Start() {
        bpsBase = bps;
        targetingRangeBase = targetingRange;

        upgradeButton.onClick.AddListener(Upgrade);
    }

    // Main update loop for the turret
    private void Update() {
        // If there is no target, find one
        if (target == null){
            FindTarget();
            return;
        }

        // Rotate the turret towards the target
        RotateTowardsTarget();

        // If the target is out of range, set it to null
        if (!CheckTargetIsInRange()) {
            target = null;
        } else {
            // Fire bullets at the target with the specified rate
            timeUntilFire += Time.deltaTime;

            if (timeUntilFire >= 1f / bps) {
                Shoot();
                timeUntilFire = 0f;
            }
        }
    }

    // Instantiate a bullet and set its target
    private void Shoot() {
        GameObject bulletObj = Instantiate(bulletPrefab, firingPoint.position, Quaternion.identity);
        Bullet bulletScript = bulletObj.GetComponent<Bullet>();
        bulletScript.SetTarget(target);
    }

    // Find a target within the turret's range using a circle cast
    private void FindTarget() {
        RaycastHit2D[] hits = Physics2D.CircleCastAll(transform.position, targetingRange, (Vector2)transform.position, 0f, enemyMask);

        if (hits.Length > 0) {
            target = hits[0].transform;
        }
    }

    // Check if the target is within the turret's range
    private bool CheckTargetIsInRange() {
        return Vector2.Distance(target.position, transform.position) <= targetingRange;
    }

    // Rotate the turret towards the target
    private void RotateTowardsTarget() {
        float angle = Mathf.Atan2(target.position.y - transform.position.y, target.position.x - transform.position.x) * Mathf.Rad2Deg - 90f;

        Quaternion targetRotation = Quaternion.Euler(new Vector3(0f, 0f, angle));
        turretRotationPoint.rotation = Quaternion.RotateTowards(turretRotationPoint.rotation, targetRotation, rotationSpeed * Time.deltaTime);
    }

    // Open the upgrade UI
    public void OpenUpgradeUI () {
        upgradeUI.SetActive(true);
    }

    // Close the upgrade UI and update the hovering state in the UIManager
    public void CloseUpgradeUI() {
        upgradeUI.SetActive(false);
        UIManager.main.SetHoveringState(false);
    }

    // Upgrade the turret's level, adjust attributes, and spend currency
    public void Upgrade() {
        // Check if there's enough currency for the upgrade
        if (CalculateCost() > LevelManager.main.currency) return;

        // Spend currency, increase level, and adjust attributes
        LevelManager.main.SpendCurrency(CalculateCost());
        level++;
        bps = CalculateBPS();
        targetingRange = CalculateRange();

        // Close the upgrade UI and log the new values
        CloseUpgradeUI();
        Debug.Log("New BPS: " + bps);
        Debug.Log("New Range: " + targetingRange);
        Debug.Log("New Cost: " + CalculateCost());
    }

    // Calculate the cost of the next upgrade based on a formula
    private int CalculateCost(){
        return Mathf.RoundToInt(baseUpgradeCost * Mathf.Pow(level, 0.8f));
    }

    // Calculate the new bullets per second based on the level
    private float CalculateBPS() {
        return bpsBase * Mathf.Pow(level, 0.6f);
    }

    // Calculate the new targeting range based on the level
    private float CalculateRange() {
        return targetingRangeBase * Mathf.Pow(level, 0.4f);
    }

    // Draw a visual representation of the targeting range in the Scene view
    private void OnDrawGizmosSelected() {
        Handles.color = Color.cyan;
        Handles.DrawWireDisc(transform.position, transform.forward, targetingRange);
    }
}